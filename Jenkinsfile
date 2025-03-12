pipeline {
    agent any  
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))  // Keep last 5 builds only
    }
    environment {
        WORKSPACE = "${env.WORKSPACE}"
        SERVICES_WITHOUT_TESTS = "spring-petclinic-admin-server spring-petclinic-genai-service"
    }

    stages {
        stage('Checkout Code') {
            steps {
                script {
                    sh '''
                    # Clone the forked repo only if it doesn't exist
                    if [ ! -d DevOps_Project1 ]; then
                        git clone https://github.com/22127063/DevOps_Project1.git
                    fi
                    cd DevOps_Project1
                    git pull origin main
                    '''
                }
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    echo "Running pipeline for Branch: ${env.BRANCH_NAME}"

                    def prevCommitExists = sh(script: "cd DevOps_Project1 && git rev-parse HEAD~1", returnStatus: true) == 0
                    def changedFiles = prevCommitExists 
                        ? sh(script: "cd DevOps_Project1 && git diff --name-only HEAD~1 HEAD", returnStdout: true).trim().split("\n")
                        : []

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

                    env.CHANGED_SERVICES = ""
                    def rebuildAll = false

                    for (service in services) {
                        if (changedFiles.find { it.contains(service) }) {
                            env.CHANGED_SERVICES = env.CHANGED_SERVICES + " " + service
                        }
                    }

                    def commonFiles = ["pom.xml", ".github", "docker-compose.yml", "Jenkinsfile"]
                    if (changedFiles.find { file -> commonFiles.any { file.contains(it) } }) {
                        rebuildAll = true
                        env.CHANGED_SERVICES = services.join(" ")
                    }

                    if (env.CHANGED_SERVICES == "") {
                        echo "No relevant changes detected. Skipping pipeline."
                        currentBuild.result = 'SUCCESS'
                        return
                    }

                    echo "Services to build: ${env.CHANGED_SERVICES}"
                }
            }
        }
        
        stage('Test Services') {
            when {
                expression { return env.CHANGED_SERVICES != "" }
            }
            steps {
                script {
                    def serviceList = env.CHANGED_SERVICES.trim().split(" ")
                    for (service in serviceList) {
                        echo "Testing service: ${service}"
                        dir("DevOps_Project1/${service}") {
                            // ✅ **Check if `pom.xml` exists**
                            if (fileExists('pom.xml')) {
                                echo "✅ pom.xml found in ${service}"
                                if (!env.SERVICES_WITHOUT_TESTS.contains(service)) {
                                    try {
                                        sh 'mvn clean test'

                                        // Publish test results
                                        junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'

                                        // Publish coverage reports
                                        jacoco(
                                            execPattern: '**/target/jacoco.exec',
                                            classPattern: '**/target/classes',
                                            sourcePattern: '**/src/main/java',
                                            exclusionPattern: '**/src/test*'
                                        )
                                    } catch (Exception e) {
                                        echo "Warning: Tests failed for ${service}, but continuing pipeline"
                                        currentBuild.result = 'UNSTABLE'
                                    }
                                } else {
                                    echo "Skipping tests for ${service} as it does not have test folders"
                                }
                            } else {
                                echo "❌ pom.xml NOT FOUND in ${service}. Skipping tests."
                            }
                        }
                    }
                }
            }
        }

        stage('Check Test Coverage') {
            when {
                expression { env.CHANGED_SERVICES && env.CHANGED_SERVICES != 'main' }
            }
            steps {
                script {
                    def serviceList = env.CHANGED_SERVICES.trim().split(" ")
                    for (service in serviceList) {
                        def servicePath = "DevOps_Project1/${service}/target/site/jacoco/jacoco.csv"
                        if (fileExists(servicePath)) {
                            def coverage = sh(script: "tail -1 ${servicePath} | cut -d',' -f4", returnStdout: true).trim()
                            if (coverage.toInteger() < 70) {
                                error("Test coverage below 70% for ${service}")
                            }
                        } else {
                            echo "No coverage report found for ${service}. Skipping coverage check."
                        }
                    }
                }
            }
        }

        stage('Build Services') {
            when {
                expression { return env.CHANGED_SERVICES != "" }
            }
            steps {
                script {
                    def serviceList = env.CHANGED_SERVICES.trim().split(" ")
                    for (service in serviceList) {
                        echo "Building service: ${service}"
                        dir("DevOps_Project1/${service}") {
                            // **Check if `pom.xml` exists before building**
                            if (fileExists('pom.xml')) {
                                echo "pom.xml found in ${service}, proceeding with build."
                                sh 'mvn package -DskipTests'
                                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                            } else {
                                echo "pom.xml NOT FOUND in ${service}. Skipping build."
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs() // Clean workspace after each build to prevent leftover files
        }
    }
}
