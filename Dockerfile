# ================================
# 🌱 Stage 1: Build and extract layers
# ================================
FROM eclipse-temurin:17 AS builder

WORKDIR /application

# Default naming convention
ARG SERVICE_NAME
ARG VERSION=3.4.1
ARG ARTIFACT_NAME=spring-petclinic-${SERVICE_NAME}-${VERSION}

# Allow override of default artifact name
ARG CUSTOM_JAR_NAME
ENV FINAL_JAR_NAME=${CUSTOM_JAR_NAME:-${ARTIFACT_NAME}}

COPY spring-petclinic-${SERVICE_NAME}/target/*.jar app.jar

RUN java -Djarmode=layertools -jar app.jar extract

# ================================
# 🚀 Stage 2: Runtime image
# ================================
FROM eclipse-temurin:17-jre

WORKDIR /application

# App port from ARG (optional)
ARG EXPOSED_PORT=8080
EXPOSE ${EXPOSED_PORT}

# Active profile
ENV SPRING_PROFILES_ACTIVE docker,mysql

# Copy layers in cache-friendly order
COPY --from=builder /application/dependencies/ ./
RUN true
COPY --from=builder /application/spring-boot-loader/ ./
RUN true
COPY --from=builder /application/snapshot-dependencies/ ./
RUN true
COPY --from=builder /application/application/ ./

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
