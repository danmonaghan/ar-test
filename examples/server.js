const fs = require('fs');
const https = require('https');
const express = require('express');
const ip = require('ip');
const io = require('socket.io');
const QRCode = require('qrcode');

const SERVER_PORT = 443;
const STATIC_FOLDER = './public/';

const app = express();

app.use( ( req, response, next ) =>
{
    // response.setHeader('Access-Control-Allow-Headers', 'authorization, content-type');
    // response.setHeader('Access-Control-Allow-Headers', request.header.origin );
    response.setHeader( 'Access-Control-Allow-Headers', '*' );
    response.setHeader( 'Access-Control-Allow-Origin', '*' );
    response.setHeader( 'Access-Control-Allow-Methods', 'OPTIONS, GET' );
    response.setHeader( 'Access-Control-Request-Method', '*' );
    response.setHeader( 'Cross-Origin-Opener-Policy', 'same-origin' );
    response.setHeader( 'Cross-Origin-Embedder-Policy', 'require-corp' );
    next();
} );

app.use( express.static( STATIC_FOLDER ) );

// Generate QR code for localhost address
let qrCodeDataURL = '';
const serverUrl = `https://${ip.address()}:${SERVER_PORT}`;

QRCode.toDataURL(serverUrl, { 
    width: 200, 
    margin: 2,
    color: {
        dark: '#000000',
        light: '#FFFFFF'
    }
}).then(url => {
    qrCodeDataURL = url;
    console.log(`QR Code generated for: ${serverUrl}`);
}).catch(err => {
    console.error('Error generating QR code:', err);
});

// Route to get QR code
app.get('/qr', (req, res) => {
    if (qrCodeDataURL) {
        res.setHeader('Content-Type', 'image/png');
        const base64Data = qrCodeDataURL.replace(/^data:image\/png;base64,/, '');
        res.send(Buffer.from(base64Data, 'base64'));
    } else {
        res.status(500).send('QR code not ready');
    }
});

// Route to get server URL
app.get('/server-url', (req, res) => {
    res.json({ url: serverUrl });
});

const httpsServer = https.createServer(
    {
        key: fs.readFileSync( 'ssl/key.pem' ),
        cert: fs.readFileSync( 'ssl/cert.pem' )
    },
    app
);

httpsServer.listen( SERVER_PORT, () =>
{
    const url = `https://${ ip.address() }:${ SERVER_PORT }`;
    console.log( `Server running at: \x1b[36m${ url }\x1b[0m` );
} );

const socketServer = io( httpsServer );
socketServer.on( 'connection', ( socket ) =>
{
    socket.on( 'data', ( data ) => socketServer.emit( 'data', data ) );
} );