# ==============================================================================
# LIGHTWEIGHT PRODUCTION DOCKERFILE (NO HEAVY BUILD IN SUGA CONTAINER)
# ==============================================================================
FROM nginx:alpine

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy pre-built Flutter Web production release files directly
COPY build/web /usr/share/nginx/html

# Expose HTTP port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
