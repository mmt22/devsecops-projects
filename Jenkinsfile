pipeline {
    agent {
        kubernetes {
            yamlFile 'pod.yaml'
        }
    }

    options {
        // STOP THE LOOP: This prevents multiple builds from running at once
        disableConcurrentBuilds()
        // CLEANUP: Keeps only the last 5 builds in your history
        buildDiscarder(logRotator(numToKeepStr: '5'))
        // TIMEOUT: Fails the build if it gets stuck for more than 30 mins
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
                // Milestone ensures if you push new code, the old build stops immediately
                milestone(1)
                checkout scm
            }
        }

        stage('Snyk Security Scan') {
            steps {
                container('snyk') {
                    withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                        echo "--- Scanning Dependencies (SCA) ---"
                        // Fails the build if HIGH or CRITICAL vulnerabilities are found
                        sh "snyk test --auth-token=${SNYK_TOKEN} --severity-threshold=high"

                        echo "--- Scanning Source Code (SAST) ---"
                        // Scans your Java code for logic flaws
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
                    echo "--- Building Container and Pushing to Harbor ---"
                    sh """
                    /kaniko/executor --context `pwd` \
                    --dockerfile `pwd`/Dockerfile \
                    --destination ${HARBOR_REGISTRY}/${IMAGE_NAME}:${TAG} \
                    --skip-tls-verify --insecure
                    """
                }
            }
        }

        stage('Image Vulnerability Scan') {
            steps {
                container('snyk') {
                    withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                        echo "--- Scanning final image in Harbor ---"
                        sh "snyk container test ${HARBOR_REGISTRY}/${IMAGE_NAME}:${TAG} --auth-token=${SNYK_TOKEN} --skip-tls"
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
