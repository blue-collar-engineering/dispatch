# Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files first to leverage Docker cache
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:stable-alpine

# Copy built files from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Add nginx user, no root privileges in production
RUN adduser -D -g 'www' www && \
    chown -R www:www /usr/share/nginx/html && \
    chown -R www:www /var/cache/nginx && \
    chown -R www:www /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R www:www /var/run/nginx.pid

# Switch to non-root user
USER www

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
