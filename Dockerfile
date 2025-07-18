FROM public.ecr.aws/lambda/nodejs:18

# Set the working directory in the container
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy package.json and package-lock.json (if any) to the working directory
# This allows caching of dependencies if they don't change
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code to the working directory
COPY . .

# Command to run the application when the container starts
# This tells Lambda to execute the 'index.js' file.
# The 'CMD' specifies the handler function in the format 'filename.handler_function_name'.
# For Express apps, the Lambda runtime acts as a proxy, passing events to the Express app.
# The base image already has a default handler that expects an 'index.js' with an exported app.
CMD [ "index.handler" ]
