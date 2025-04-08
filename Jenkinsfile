pipeline {
    agent any
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }

    parameters {
        string(name: 'CUSTOMERS_BRANCH', defaultValue: 'main', description: 'Branch for customers-service')
        string(name: 'VISITS_BRANCH', defaultValue: 'main', description: 'Branch for visits-service')
        string(name: 'VETS_BRANCH', defaultValue: 'main', description: 'Branch for vets-service')
        string(name: 'GENAI_BRANCH', defaultValue: 'main', description: 'Branch for genai-service')
    }

    environment {
        SERVICES_WITHOUT_TESTS = "spring-petclinic-admin-server spring-petclinic-genai-service"
        REPO_URL = 'https://github.com/22127063/spring-petclinic-microservices.git'
        IMAGE_NAME = '22127063/devops_prj2'
    }

    stages {
        stage('Checkout All Services') {
            steps {
                script {
                    // Clone full monorepo, default to 'main'
                    git branch: 'main', url: "${REPO_URL}"

                    // Checkout specific branches for services if needed
                    def servicesWithBranches = [
                        'spring-petclinic-customers-service': params.CUSTOMERS_BRANCH,
                        'spring-petclinic-visits-service'   : params.VISITS_BRANCH,
                        'spring-petclinic-vets-service'     : params.VETS_BRANCH,
                        'spring-petclinic-genai-service'    : params.GENAI_BRANCH
                    ]

                    servicesWithBranches.each { path, branch ->
                        dir("spring-petclinic-microservices/${path}") {
                            sh "git fetch origin ${branch}"
                            sh "git checkout ${branch}"
                        }
                    }
                }
            }
        }

        stage('Detect Changes') {
            steps {
                script {
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

                    def changedServiceList = services.findAll { service ->
                        changedFiles.any { it.contains(service) }
                    }

                    def commonFiles = ["pom.xml", ".github", "docker-compose.yml", "Jenkinsfile"]
                    if (changedFiles.any { file -> commonFiles.any { file.contains(it) } }) {
                        changedServiceList = services
                    }

                    env.CHANGED_SERVICES = changedServiceList.join(" ")

                    if (env.CHANGED_SERVICES.trim().isEmpty()) {
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
                expression { return !env.CHANGED_SERVICES.trim().isEmpty() }
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
                                    recordCoverage tools: [[jacoco: '**/target/site/jacoco/jacoco.xml']]
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
                expression {
                    return !env.CHANGED_SERVICES.trim().isEmpty() &&
                           params.CUSTOMERS_BRANCH != 'main' || params.VISITS_BRANCH != 'main' ||
                           params.VETS_BRANCH != 'main' || params.GENAI_BRANCH != 'main'
                }
            }
            steps {
                script {
                    def serviceList = env.CHANGED_SERVICES.trim().split(" ")
                    for (service in serviceList) {
                        def csvPath = "spring-petclinic-microservices/${service}/target/site/jacoco/jacoco.csv"
                        if (fileExists(csvPath)) {
                            def coverage = sh(script: "tail -1 ${csvPath} | cut -d',' -f4", returnStdout: true).trim()
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

        stage('Build and Push Docker Image') {
            when {
                expression { return !env.CHANGED_SERVICES.trim().isEmpty() }
            }
            steps {
                script {
                    def serviceBranches = [
                        'spring-petclinic-customers-service': params.CUSTOMERS_BRANCH,
                        'spring-petclinic-visits-service'   : params.VISITS_BRANCH,
                        'spring-petclinic-vets-service'     : params.VETS_BRANCH,
                        'spring-petclinic-genai-service'    : params.GENAI_BRANCH
                    ]

                    for (entry in serviceBranches) {
                        def service = entry.key
                        def branch = entry.value
                        if (env.CHANGED_SERVICES.contains(service)) {
                            def shortName = service.replace("spring-petclinic-", "")
                            def commitId = sh(script: "cd spring-petclinic-microservices/${service} && git rev-parse --short HEAD", returnStdout: true).trim()
                            def imageTag = "${IMAGE_NAME}/${shortName}:${commitId}"

                            echo "Building Docker image for ${service}"
                            sh """
                                cd spring-petclinic-microservices/${service}
                                docker build -t ${imageTag} .
                                docker push ${imageTag}
                            """
                        } else {
                            echo "Skipping Docker build for ${service}"
                        }
                    }
                }
            }
        }

        stage('Build Services') {
            when {
                expression { return !env.CHANGED_SERVICES.trim().isEmpty() }
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

