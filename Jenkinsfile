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

        stage('Snyk Security Scan') {
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

        // --- FIXED SECTION BELOW ---
        stage('Image Vulnerability Scan') { 
            steps {
                container('snyk') {
                    // 1. Fetch BOTH Snyk token and Harbor Credentials
                    withCredentials([
                        string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN'),
                        usernamePassword(credentialsId: 'harbor-creds', usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PASS')
                    ]) {
                        // 2. Pass Harbor creds as Env Vars so Snyk can pull the image
                        withEnv(["SNYK_REGISTRY_USERNAME=${HARBOR_USER}", "SNYK_REGISTRY_PASSWORD=${HARBOR_PASS}"]) {
                            echo "--- Scanning final image in Harbor ---"
                            
                            // 3. SECURE SYNTAX: Use single quotes to prevent secret leakage in logs
                            // Added '-d' for debug output if it fails again
                            sh 'snyk container test $HARBOR_REGISTRY/$IMAGE_NAME:$TAG --auth-token=$SNYK_TOKEN --skip-tls -d'
                        }
                    }
                }
            }
        }
        // --- END FIXED SECTION ---
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