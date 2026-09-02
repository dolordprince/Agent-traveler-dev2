FROM node:22-alpine

WORKDIR /app

# Copy root configurations
COPY package*.json ./

# Copy source directory (adjust path if your React app is inside a folder)
COPY . .

# Install dependencies and build static assets
RUN npm ci || npm install

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]
