pipeline {
    agent {
        kubernetes {
            yamlFile 'pod.yaml' // Point to the pod definition above
        }
    }

    environment {
        HARBOR_REGISTRY = "12.0.1.12"
        IMAGE_NAME = "library/secure-app"
        TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout Source') {
            steps {
                checkout scm
            }
        }

        stage('Snyk Security Scan (SAST & SCA)') {
            steps {
                container('snyk') {
                    withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                        echo "--- Checking Maven Dependencies (SCA) ---"
                        sh "snyk test --auth-token=${SNYK_TOKEN} --severity-threshold=high"

                        echo "--- Checking Java Source Code (SAST) ---"
                        sh "snyk code test --auth-token=${SNYK_TOKEN}"
                    }
                }
            }
        }

        stage('Maven Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Build & Push Image (Kaniko)') {
            steps {
                container('kaniko') {
                    // Builds the image and pushes to your Harbor VM
                    sh """
                    /kaniko/executor --context `pwd` \
                    --dockerfile `pwd`/Dockerfile \
                    --destination ${HARBOR_REGISTRY}/${IMAGE_NAME}:${TAG} \
                    --skip-tls-verify --insecure
                    """
                }
            }
        }

        stage('Final Container Scan') {
            steps {
                container('snyk') {
                    withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                        echo "--- Scanning Final Image Layers ---"
                        // Scans the image pushed to Harbor for OS vulnerabilities
                        sh "snyk container test ${HARBOR_REGISTRY}/${IMAGE_NAME}:${TAG} --auth-token=${SNYK_TOKEN} --skip-tls"
                    }
                }
            }
        }
    }
}
