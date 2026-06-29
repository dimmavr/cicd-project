pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'echo "Build stage on $(hostname)"'
                sh 'bash app.sh'
            }
        }
        stage('Deploy') {
            steps {
                sh 'echo "Deploy stage starting..."'
                sh 'bash deploy.sh'
            }
        }
    }
}
