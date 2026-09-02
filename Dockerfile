FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm install --production || true

COPY . .

EXPOSE 7860

CMD ["node", "server.js"]
