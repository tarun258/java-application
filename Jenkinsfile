#!/usr/bin/env groovy

pipeline {
    agent { label 'executor-v2' }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    stages {
        stage('Build Image')
            steps {
                sh './build.sh'
            }

        stage('Test')
            steps {
                sh './test.sh'

                junit 'build/test-results/test/*.xml'
            }

        stage('Publish')
            steps {
                sh './publish.sh'
            }
    }

    post {
        always {
            cleanupAndNotify(currentBuild.currentResult)
        }
    }
}