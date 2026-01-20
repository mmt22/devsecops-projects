pipeline {
    agent {
        kubernetes {
            // This label ensures the pod is unique per build
            label 'devsecops-agent'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    some-label: some-value
spec:
  containers:
  # 1. The Builder (Maven + Java)
  - name: maven
    image: maven:3.9.6-eclipse-temurin-17
    command:
    - cat
    tty: true
    
  # 2. The Image Builder (Kaniko - No Docker Daemon needed!)
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: harbor-secret-vol
      mountPath: /kaniko/.docker
  
  # Mount the Secret we created in Step 2
  volumes:
  - name: harbor-secret-vol
    secret:
      secretName: harbor-creds
      items:
      - key: .dockerconfigjson
        path: config.json
"""
        }
    }

    environment {
        // Your Harbor Details
        REGISTRY = '12.0.1.12'
        PROJECT = 'library'
        APP_NAME = 'secure-pipeline-demo'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Test (Maven)') {
            steps {
                container('maven') {
                    // Run Maven inside the 'maven' container defined above
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Build & Push (Kaniko)') {
            steps {
                container('kaniko') {
                    // Kaniko magic: Builds and Pushes securely
                    // --skip-tls-verify is NEEDED for self-signed Harbor certs
                    sh """
                    /kaniko/executor \
                        --context `pwd` \
                        --dockerfile `pwd`/Dockerfile \
                        --destination ${REGISTRY}/${PROJECT}/${APP_NAME}:${IMAGE_TAG} \
                        --destination ${REGISTRY}/${PROJECT}/${APP_NAME}:latest \
                        --skip-tls-verify \
                        --insecure
                    """
                }
            }
        }
    }
}