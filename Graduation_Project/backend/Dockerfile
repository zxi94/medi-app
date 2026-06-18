# Use Node.js 
FROM node:18

# Create app directory
WORKDIR /usr/src/app

# Install dependencies
COPY package*.json ./
RUN npm install

# Bundle app source
COPY . .

# Match the port you've been using in Flutter
EXPOSE 5001

# Start the server
CMD [ "node", "src/app.js" ] 
