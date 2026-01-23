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
        HARBOR_REGISTRY = "12.0.1.12:80"
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
                        // FIX: Single quotes prevent 'Insecure Interpolation' warning
                        sh 'snyk test --auth-token=$SNYK_TOKEN --severity-threshold=high'

                        echo "--- Scanning Source Code (SAST) ---"
                        sh 'snyk code test --auth-token=$SNYK_TOKEN'
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
                    echo "--- Building Container (Chainguard), Pushing, and Saving Tarball ---"
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
                        sh 'snyk container test docker-archive:image.tar --file=Dockerfile --auth-token=$SNYK_TOKEN --severity-threshold=high'
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                // PART 1: PREPARE (Run on the Agent)
                // The Jenkins Agent (Maven container) has 'sed' and write permissions.
                script {
                    echo "--- Preparing Manifests (Running on Agent) ---"
                    sh "sed -i 's|IMAGE_PLACEHOLDER|${HARBOR_REGISTRY}/${IMAGE_NAME}:${TAG}|g' k8s-deployment.yaml"
                }

                // PART 2: APPLY (Run on the Sidecar)
                // The Kubectl container only needs to run 'kubectl'.
                container('kubectl') {
                    echo "--- Deploying to Cluster (Running in Sidecar) ---"
                    sh 'kubectl apply -f k8s-deployment.yaml'
                    echo "--- Application Deployed Successfully ---"
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