FROM node:20-alpine

WORKDIR /app

COPY backend/package*.json ./
RUN npm install --production

COPY backend ./

ENV NODE_ENV=production

EXPOSE 3000

CMD ["node", "src/institutional/server.js"]
