# ========== STAGE 1: Build and extract layers ==========
FROM eclipse-temurin:17 AS builder

# Nhận biến từ Jenkins hoặc build script
ARG SERVICE_NAME
WORKDIR /application

# Copy JAR từ thư mục build tương ứng
COPY spring-petclinic-${SERVICE_NAME}/target/*.jar application.jar

# Dùng layertools để tách tầng
RUN java -Djarmode=layertools -jar application.jar extract


# ========== STAGE 2: Final image ==========
FROM eclipse-temurin:17-jdk-jammy

# Nhận lại các biến
ARG SERVICE_NAME
ARG EXPOSED_PORT

ENV SERVICE_NAME=${SERVICE_NAME}
ENV SPRING_PROFILES_ACTIVE=docker

WORKDIR /app
EXPOSE ${EXPOSED_PORT}

# Copy từng phần từ builder để tận dụng layer cache
COPY --from=builder /application/dependencies/ ./
COPY --from=builder /application/spring-boot-loader/ ./
COPY --from=builder /application/snapshot-dependencies/ ./
COPY --from=builder /application/application/ ./

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
