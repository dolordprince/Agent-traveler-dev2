# Step 1: Build the static frontend app
FROM node:22-alpine AS builder

WORKDIR /app

# Check if webcontainer-ui subfolder exists, otherwise build from root
COPY . .

RUN if [ -d "webcontainer-ui" ]; then \
      cd webcontainer-ui && npm install && npm run build && cp -r dist /app/dist; \
    else \
      npm install && npm run build; \
    fi

# Step 2: Serve the built static files on port 7860 using serve
FROM node:22-alpine

WORKDIR /app

RUN npm install -g serve

COPY --from=builder /app/dist /app/dist

EXPOSE 7860

CMD ["serve", "-s", "dist", "-l", "7860"]
