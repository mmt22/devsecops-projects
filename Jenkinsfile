pipeline {
    agent {
        kubernetes {
            yamlFile 'pod.yaml'
        }
    }

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        HARBOR_REGISTRY = "12.0.1.12"
        IMAGE_NAME = "library/secure-app"
        TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                milestone(1)
                checkout scm
            }
        }

        stage('Snyk Security Scan (Code & Deps)') {
            steps {
                container('snyk') {
                    withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                        echo "--- Scanning Dependencies (SCA) ---"
                        sh "snyk test --auth-token=${SNYK_TOKEN} --severity-threshold=high"

                        echo "--- Scanning Source Code (SAST) ---"
                        sh "snyk code test --auth-token=${SNYK_TOKEN}"
                    }
                }
            }
        }

        stage('Build Artifact') {
            steps {
                container('maven') {
                    echo "--- Compiling Java Code ---"
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Build & Push to Harbor') {
            steps {
                container('kaniko') {
                    echo "--- Building Container, Pushing to Harbor, and Saving Tarball ---"
                    // Added --tarPath to save a local copy for scanning
                    sh """
                    /kaniko/executor --context `pwd` \
                    --dockerfile `pwd`/Dockerfile \
                    --destination ${HARBOR_REGISTRY}/${IMAGE_NAME}:${TAG} \
                    --tarPath image.tar \
                    --skip-tls-verify --insecure
                    """
                }
            }
        }

        stage('Image Vulnerability Scan') {
            steps {
                container('snyk') {
                    withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                        echo "--- Scanning local image artifact (Bypassing Network) ---"
                        
                        // FIX: Scan the local 'image.tar' file instead of pulling from Harbor
                        // This fixes the HTTP vs HTTPS mismatch error
                        sh 'snyk container test docker-archive:image.tar --file=Dockerfile --auth-token=$SNYK_TOKEN --severity-threshold=high'
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "Pipeline finished."
        }
        failure {
            echo "Security or Build failure detected. Please check the logs."
        }
    }
}