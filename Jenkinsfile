pipeline {
  agent any
  
  stages {
    stage('Clean Workspace') {
      steps {
        cleanWs()
      }
    }

    stage('Clean Docker Environment') {
      steps {
        sh 'docker system prune -f'
      }
    }

    stage('Clone GitHub Repo') {
      steps {
        git branch: 'master', url: 'https://github.com/Balaji93bobby/benotes.git'
      }
    }

    stage('Generate Build Number Tag (Optional)') {
      steps {
        script {
          // Define a versioning logic here (optional)
          // For example:
          def buildNumber = env.BUILD_NUMBER ?: "latest"  // Use BUILD_NUMBER or default to "latest"
          def imageTag = "benotes-app:${buildNumber}"
          env.DOCKER_IMAGE_TAG = imageTag  // Store build tag as environment variable
        }
      }
    }

    stage('Build') {
      steps {
        sh "docker build -t ${env.DOCKER_IMAGE_TAG} ."  // Use environment variable or default
      }
    }

    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
          sh "docker login -u $USERNAME -p $PASSWORD"
          // Use environment variable for registry URL (optional)
          sh "docker tag ${env.DOCKER_IMAGE_TAG} ${env.REGISTRY_URL ?: ''}balaji93bobby/benotes-app:${env.DOCKER_IMAGE_TAG.split(':')[1]}"
          sh "docker push ${env.REGISTRY_URL ?: ''}balaji93bobby/benotes-app:${env.DOCKER_IMAGE_TAG.split(':')[1]}"
        }
      }
    }

    stage('Update and Apply Deployment') {
      steps {
        script {
          // Read deployment file content
          def deploymentFileContent = readFile('deployment.yaml')

          // Update image tag with build tag
          deploymentFileContent = deploymentFileContent.replaceAll(/image: balaji93bobby\/benotes-app:.*/, "image: balaji93bobby/benotes-app:${env.DOCKER_IMAGE_TAG.split(':')[1]}")

          // Write updated deployment file content
          writeFile file: 'deployment.yaml', text: deploymentFileContent

          withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
            // Apply deployment with kubectl (assuming kubeconfig is available)
            sh "kubectl apply -f deployment.yaml -n benotes"
          }
        }
      }
    }

    stage('Apply Kubernetes Service') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
          sh "kubectl --kubeconfig=$KUBECONFIG apply -f service.yaml -n benotes"
        }
      }
    }
  }
}
