#!/usr/bin/groovy

// load pipeline functions
// Requires pipeline-github-lib plugin to load library from github

@Library('github.com/jdeiviz/jenkins-pipeline@more-secure')

def pipeline = new jenkinsloveskubernetes.lib.Pipeline()

podTemplate(label: 'jenkins-pipeline', serviceAccount: 'jenkins', containers: [
    containerTemplate(name: 'jnlp', image: 'jenkins/jnlp-slave:3.27-1-alpine', args: '${computer.jnlpmac} ${computer.name}', workingDir: '/home/jenkins', resourceRequestCpu: '200m', resourceLimitCpu: '300m', resourceRequestMemory: '256Mi', resourceLimitMemory: '512Mi'),
    containerTemplate(name: 'kaniko', image: 'gcr.io/kaniko-project/executor:debug', command: '/busybox/cat', ttyEnabled: true),
    containerTemplate(name: 'golang', image: 'golang:1.8.3', command: 'cat', ttyEnabled: true),
    containerTemplate(name: 'helm', image: 'lachlanevenson/k8s-helm:v2.12.2', command: 'cat', ttyEnabled: true),
    containerTemplate(name: 'kubectl', image: 'lachlanevenson/k8s-kubectl:v1.11.6', command: 'cat', ttyEnabled: true)
],
volumes:[
    secretVolume(secretName: 'reg-cred', mountPath: '/kaniko/.docker')
]){

  node ('jenkins-pipeline') {

    def pwd = pwd()
    def chart_dir = "${pwd}/charts/croc-hunter"

    checkout scm

    // read in required jenkins workflow config values
    def inputFile = readFile('Jenkinsfile.json')
    def config = new groovy.json.JsonSlurperClassic().parseText(inputFile)
    println "pipeline config ==> ${config}"

    // continue only if pipeline enabled
    if (!config.pipeline.enabled) {
        println "pipeline disabled"
        return
    }

    // set additional git envvars for image tagging
    pipeline.gitEnvVars()

    // If pipeline debugging enabled
    if (config.pipeline.debug) {
      println "DEBUG ENABLED"
      sh "env | sort"

      println "Runing kubectl/helm tests"
      container('kubectl') {
        pipeline.kubectlTest()
      }
      container('helm') {
        pipeline.helmConfig()
      }
    }

    def acct = pipeline.getContainerRepoAcct(config)

    // tag image with version, and branch-commit_id
    def image_tags_map = pipeline.getContainerTags(config)

    // compile tag list
    def image_tags_list = pipeline.getMapValues(image_tags_map)

    stage ('compile and test') {

      container('golang') {
        sh "go test -v -race ./..."
        sh "make bootstrap build"
      }
    }

    stage ('test deployment') {

      container('helm') {

        // run helm chart linter
        pipeline.helmLint(chart_dir)

      }
    }

    stage ('publish container') {

      container(name: 'kaniko', shell: '/busybox/sh') {

        // build and publish container

        pipeline.containerBuildPub(
            dockerfile: config.container_repo.dockerfile,
            host      : config.container_repo.host,
            acct      : acct,
            repo      : config.container_repo.repo,
            tags      : image_tags_list,
            auth_id   : config.container_repo.jenkins_creds_id,
            image_scanning: config.container_repo.image_scanning
        )
      }


    }
    

    if (env.BRANCH_NAME =~ "PR-*" ) {
      stage ('deploy to k8s') {
        container('helm') {
          // Deploy using Helm chart
          pipeline.helmTemplate(
            name          : env.BRANCH_NAME.toLowerCase(),
            namespace     : config.app.namespace,
            chart_dir     : chart_dir,
            set           : [
              "image": "${config.container_repo.host}/${acct}/${config.container_repo.repo}",
              "imageTag": image_tags_list.get(0),
              "replicas": config.app.replicas,
              "cpu": config.app.cpu,
              "memory": config.app.memory,
              "ingress.hostname": config.app.hostname,
            ]
          )
        }
        container('kubectl') {
          pipeline.kubectlDeploy(
            name          : env.BRANCH_NAME.toLowerCase(),
          )
          // delete test deployment
          pipeline.kubectlDelete(
              name       : env.BRANCH_NAME.toLowerCase()
          )
        }
      }
    }

    // deploy only the master branch
    if (env.BRANCH_NAME == 'master' || env.BRANCH_NAME == 'more-secure') {
      stage ('deploy to k8s') {
        container('helm') {
          // Deploy using Helm chart
          pipeline.helmTemplate(
            name          : config.app.name,
            namespace     : config.app.namespace,
            chart_dir     : chart_dir,
            set           : [
              "image": "${config.container_repo.host}/${acct}/${config.container_repo.repo}",
              "imageTag": image_tags_list.get(0),
              "replicas": config.app.replicas,
              "cpu": config.app.cpu,
              "memory": config.app.memory,
              "ingress.hostname": config.app.hostname,
            ]
          )
        }
        container('kubectl') {
          pipeline.kubectlDeploy(
            name          : env.BRANCH_NAME.toLowerCase(),
          )
        }
      }
    }
  }
}
