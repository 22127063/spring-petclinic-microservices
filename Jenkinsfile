pipeline {
    agent any  
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
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
                    if [ ! -d spring-petclinic-microservices ]; then
                        git clone https://github.com/22127063/spring-petclinic-microservices.git
                    fi
                    cd spring-petclinic-microservices
                    git reset --hard HEAD
                    git pull origin main
                    '''
                }
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    echo "Running pipeline for Branch: ${env.BRANCH_NAME}"

                    def prevCommitExists = sh(script: "cd spring-petclinic-microservices && git rev-parse HEAD~1", returnStatus: true) == 0
                    def changedFiles = prevCommitExists 
                        ? sh(script: "cd spring-petclinic-microservices && git diff --name-only HEAD~1 HEAD", returnStdout: true).trim().split("\n")
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

                    def changedServiceList = []
                    for (service in services) {
                        if (changedFiles.find { it.contains(service) }) {
                            changedServiceList << service
                        }
                    }

                    def commonFiles = ["pom.xml", ".github", "docker-compose.yml", "Jenkinsfile"]
                    if (changedFiles.find { file -> commonFiles.any { file.contains(it) } }) {
                        changedServiceList = services
                    }

                    env.CHANGED_SERVICES = changedServiceList.join(" ")

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
                        echo "🔬 Testing service: ${service}"
                        dir("spring-petclinic-microservices/${service}") {
                            if (fileExists('pom.xml')) {
                                echo "pom.xml found in ${service}"
                                if (!env.SERVICES_WITHOUT_TESTS.contains(service)) {
                                    try {
                                        sh 'mvn clean test -Dspring.cloud.config.enabled=false'
                                    } catch (Exception e) {
                                        echo "Warning: Tests failed for ${service}, but continuing pipeline"
                                        currentBuild.result = 'UNSTABLE'
                                    }
                                    
                                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
                                    publishCoverage adapters: [jacocoAdapter('**/target/site/jacoco/jacoco.xml')]
                                } else {
                                    echo "Skipping tests for ${service} (No test folders)"
                                }
                            } else {
                                echo "pom.xml NOT FOUND in ${service}. Skipping tests."
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
                        def servicePath = "spring-petclinic-microservices/${service}/target/site/jacoco/jacoco.csv"
                        if (fileExists(servicePath)) {
                            def coverage = sh(script: "tail -1 ${servicePath} | cut -d',' -f4", returnStdout: true).trim()
                            if (coverage.toInteger() < 70) {
                                error("Test coverage below 70% for ${service}")
                            }
                        } else {
                            error("Coverage report missing for ${service}")
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
                        dir("spring-petclinic-microservices/${service}") {
                            if (fileExists('pom.xml')) {
                                echo "pom.xml found in ${service}, proceeding with build."
                                sh 'mvn package -DskipTests -Dspring.cloud.config.enabled=false'
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
            cleanWs()
        }
    }
}
