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
                        // FIX: Use single quotes (') to prevent "Insecure Interpolation" warning
                        sh 'snyk test --auth-token=$SNYK_TOKEN --severity-threshold=high'

                        echo "--- Scanning Source Code (SAST) ---"
                        // FIX: Use single quotes (') here as well
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
                        // Using 'docker-archive:' for local scan
                        sh 'snyk container test docker-archive:image.tar --file=Dockerfile --auth-token=$SNYK_TOKEN --severity-threshold=high'
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    echo "--- Deploying to Namespace: secure-app-ns ---"
                    
                    // 1. Replace Placeholders in YAML with actual Registry/Tag
                    sh """
                    sed -i 's|HARBOR_REGISTRY_PLACEHOLDER|${HARBOR_REGISTRY}|g' k8s-deployment.yaml
                    sed -i 's|TAG_PLACEHOLDER|${TAG}|g' k8s-deployment.yaml
                    """

                    // 2. Apply the Manifests
                    // Note: This assumes your Jenkins ServiceAccount has permissions to create Namespaces/Deployments
                    sh 'kubectl apply -f k8s-deployment.yaml'
                    
                    echo "--- Application Deployed Successfully ---"
                    echo "Access URL: http://<YOUR_NODE_IP>/secure-app"
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