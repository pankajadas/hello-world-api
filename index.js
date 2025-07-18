const express = require('express');
const app = express();
const port = 3000; // Port for local testing, not directly used by Lambda

// Middleware for JWT authentication (simplified for demonstration)
const authenticateJWT = (req, res, next) => {
    // In a real application, you would:
    // 1. Get the token from the Authorization header (Bearer <token>)
    // 2. Verify the token's signature and expiration using a library like 'jsonwebtoken'
    // 3. Extract user information from the token's payload
    // 4. Attach user info to req.user for downstream handlers

    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.split(' ')[1];
        // For this example, we're just checking if a token is present.
        // In a real scenario, you'd verify it: jwt.verify(token, process.env.JWT_SECRET, (err, user) => { ... });
        console.log('Token found:', token);
        // Simulate successful authentication
        req.user = { id: 'user123', name: 'Authenticated User' }; // Attach dummy user info
        next();
    } else {
        console.log('No Authorization header or invalid format.');
        return res.status(401).json({ message: 'Authentication required. Missing or invalid Authorization header.' });
    }
};

// Public endpoint
app.get('/', (req, res) => {
    res.json({ message: 'Welcome to the API! Try /hello for a secured endpoint.' });
});

// Protected endpoint with JWT authentication
app.get('/hello', authenticateJWT, (req, res) => {
    // If authentication passes, req.user will be available
    res.json({ message: `Hello, World! You are authenticated as ${req.user.name}.` });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).send('Something broke!');
});

// Export the Express app as a Lambda handler
// This is crucial for AWS Lambda to integrate with Express
// We use 'serverless-http' or a similar wrapper in a real scenario,
// but for a simple HTTP API, Lambda's proxy integration can directly handle Express.
// For this example, we'll assume API Gateway Lambda Proxy Integration.
// The actual Lambda handler will wrap this Express app.

// This part is for local testing:
if (process.env.NODE_ENV !== 'production') {
    app.listen(port, () => {
        console.log(`App listening at http://localhost:${port}`);
        console.log('Test public endpoint: GET http://localhost:3000/');
        console.log('Test protected endpoint: GET http://localhost:3000/hello with Authorization: Bearer <any_token>');
    });
}

// For AWS Lambda, we'll wrap this Express app in a Lambda handler function.
// This is typically done in a separate file or directly in the Dockerfile's CMD.
// For Docker-based Lambda, the Dockerfile will run this index.js directly.
// The AWS Lambda runtime will then handle the HTTP events and pass them to Express.
