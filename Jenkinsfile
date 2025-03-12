pipeline {
    agent any  // Ensures the pipeline runs on an available agent

    stages {
        stage('Setup') {
            steps {
                script {
                    node {
                        def mvnHome = tool name: 'Maven 3.8.1', type: 'maven'
                        echo "Maven home: ${mvnHome}"
                        }
                    }
                }
            }
        }
    }
    stages {
        stage('Detect Changes') {
            agent { label 'agent-main' }
            steps {
                script {
                    def changes = sh(script: "git diff --name-only HEAD~1", returnStdout: true).trim()
                    def services = ['customers-service', 'vets-service', 'visit-service']

                    // Check which service changed
                    def changedService = services.find { changes.contains(it) }

                    if (changedService) {
                        echo "Detected changes in ${changedService}, delegating to service agent."
                        env.SERVICE_CHANGED = changedService
                    } else {
                        echo "No specific service changes, running full build."
                        env.SERVICE_CHANGED = "main"
                    }
                }
            }
        }

        stage('Run Tests') {
            when {
                expression { env.SERVICE_CHANGED }
            }
            steps {
                script {
                    def agentLabel = env.SERVICE_CHANGED == 'main' ? 'agent-main' : 'agent-service'
                    node(agentLabel) {
                        if (env.SERVICE_CHANGED == "main") {
                            echo "Running full test suite on agent-main..."
                            sh "mvn clean test"
                        } else {
                            echo "Running tests for ${env.SERVICE_CHANGED} on agent-service..."
                            sh "cd ${env.SERVICE_CHANGED} && mvn test"
                        }
                    }
                }
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                    jacoco execPattern: '**/target/jacoco.exec'
                }
            }
        }

        stage('Check Test Coverage') {
            when {
                expression { env.SERVICE_CHANGED && env.SERVICE_CHANGED != 'main' }
            }
            steps {
                script {
                    def coverage = sh(script: "tail -1 ${env.SERVICE_CHANGED}/target/site/jacoco/jacoco.csv | cut -d',' -f4", returnStdout: true).trim()
                    if (coverage.toInteger() < 70) {
                        error("Test coverage below 70% for ${env.SERVICE_CHANGED}")
                    }
                }
            }
        }

        stage('Build') {
            when {
                expression { env.SERVICE_CHANGED }
            }
            steps {
                script {
                    def agentLabel = env.SERVICE_CHANGED == 'main' ? 'agent-main' : 'agent-service'
                    node(agentLabel) {
                        if (env.SERVICE_CHANGED == "main") {
                            echo "Building full application on agent-main..."
                            sh "mvn clean package -DskipTests"
                        } else {
                            echo "Building ${env.SERVICE_CHANGED} on agent-service..."
                            sh "cd ${env.SERVICE_CHANGED} && mvn package -DskipTests"
                        }
                    }
                }
            }
        }
    }
}
