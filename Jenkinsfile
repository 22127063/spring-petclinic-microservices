pipeline {
    agent any  // Runs on any available agent

    stages {
        stage('Setup') {
            steps {
                script {
                    def mvnHome = tool name: 'Maven 3.8.6', type: 'maven'
                    echo "Maven home: ${mvnHome}"
                }
            }
        }

        stage('Detect Changes') {
            agent { label 'agent-main' }
            steps {
                script {
                    def changes = sh(script: "git diff --name-only HEAD~1", returnStdout: true).trim()
                    def services = [
                        'spring-petclinic-admin-server',
                        'spring-petclinic-api-gateway',
                        'spring-petclinic-config-server',
                        'spring-petclinic-customers-service',
                        'spring-petclinic-discovery-server',
                        'spring-petclinic-genai-service',
                        'spring-petclinic-vets-service',
                        'spring-petclinic-visits-service'
                    ]

                    // Check which services have changes
                    def changedServices = services.findAll { changes.contains(it) }

                    if (changedServices) {
                        echo "Detected changes in: ${changedServices}"
                        env.SERVICES_CHANGED = changedServices.join(',')
                    } else {
                        echo "No specific service changes, running full build."
                        env.SERVICES_CHANGED = "all"
                    }
                }
            }
        }

        stage('Run Tests') {
            when {
                expression { env.SERVICES_CHANGED }
            }
            steps {
                script {
                    def servicesToTest = env.SERVICES_CHANGED == "all" ? services : env.SERVICES_CHANGED.split(',')
                    
                    servicesToTest.each { service ->
                        def testFolderExists = sh(script: "[ -d ${service}/src/test ] && echo true || echo false", returnStdout: true).trim()

                        if (testFolderExists == "true") {
                            node('agent-service') {
                                echo "Running tests for ${service}..."
                                sh "cd ${service} && mvn test"
                            }
                        } else {
                            echo "Skipping tests for ${service} (No test folder)."
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
                expression { env.SERVICES_CHANGED && env.SERVICES_CHANGED != 'all' }
            }
            steps {
                script {
                    env.SERVICES_CHANGED.split(',').each { service ->
                        def testFolderExists = sh(script: "[ -d ${service}/src/test ] && echo true || echo false", returnStdout: true).trim()

                        if (testFolderExists == "true") {
                            def coverage = sh(script: "tail -1 ${service}/target/site/jacoco/jacoco.csv | cut -d',' -f4", returnStdout: true).trim()
                            if (coverage.toInteger() < 70) {
                                error("Test coverage below 70% for ${service}")
                            }
                        }
                    }
                }
            }
        }

        stage('Build') {
            when {
                expression { env.SERVICES_CHANGED }
            }
            steps {
                script {
                    def servicesToBuild = env.SERVICES_CHANGED == "all" ? services : env.SERVICES_CHANGED.split(',')

                    servicesToBuild.each { service ->
                        node('agent-service') {
                            echo "Building ${service}..."
                            sh "cd ${service} && mvn clean package -DskipTests"
                        }
                    }
                }
            }
        }
    }
}
