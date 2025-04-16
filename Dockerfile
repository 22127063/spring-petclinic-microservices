# Base runtime image
FROM eclipse-temurin:17-jdk-jammy

# Arguments passed from Jenkins
ARG SERVICE_NAME
ARG EXPOSED_PORT

ENV SERVICE_NAME=${SERVICE_NAME}
WORKDIR /app

# Copy the built JAR from service subfolder
COPY spring-petclinic-${SERVICE_NAME}/target/*.jar app.jar

EXPOSE ${EXPOSED_PORT}

ENTRYPOINT ["java", "-jar", "app.jar"]
