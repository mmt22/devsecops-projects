apiVersion: v1
kind: Pod
metadata:
  labels:
    role: jenkins-agent
spec:
  containers:
  # 1. Maven Container
  - name: maven
    image: maven:3.9.6-eclipse-temurin-17
    command: ['sleep', '99d']
    tty: true
    volumeMounts:
    - mountPath: /home/jenkins/agent
      name: workspace-volume
      readOnly: false

  # 2. Snyk Container
  - name: snyk
    image: snyk/snyk:maven
    command: ['sleep', '99d']
    tty: true
    volumeMounts:
    - mountPath: /home/jenkins/agent
      name: workspace-volume
      readOnly: false

  # 3. Kaniko Container
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ['sleep', '99d']
    tty: true
    volumeMounts:
    - mountPath: /kaniko/.docker
      name: harbor-creds
    - mountPath: /home/jenkins/agent
      name: workspace-volume
      readOnly: false

  # 4. Kubectl Container (MOVED HERE - CORRECT LOCATION)
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['cat']
    tty: true
    volumeMounts:
    - mountPath: /home/jenkins/agent
      name: workspace-volume

  volumes:
  - name: harbor-creds
    secret:
      secretName: harbor-creds
      items:
        - key: .dockerconfigjson
          path: config.json
  - name: workspace-volume
    emptyDir: {}