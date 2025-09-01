# --------- CONFIG ----------
$projectFolder = "mpesa-vercel-project"
$zipName = "$projectFolder.zip"
$splitPrefix = "mpesa-part.zip"
$splitSize = "20m"  # 20 MB chunks
$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"  # change if 7-Zip installed elsewhere
# ----------------------------

# 1. Create project folder
New-Item -ItemType Directory -Path $projectFolder -Force

# 2. Create .gitignore
@"
node_modules
.env
dist
build
*.log
"@ | Out-File -Encoding UTF8 "$projectFolder\.gitignore"

# 3. Create package.json
@"
{
  ""name"": ""mpesa-vercel-project"",
  ""version"": ""1.0.0"",
  ""main"": ""server.js"",
  ""type"": ""commonjs"",
  ""scripts"": {
    ""start"": ""node server.js"",
    ""dev"": ""nodemon server.js""
  },
  ""dependencies"": {
    ""axios"": ""^1.6.7"",
    ""dotenv"": ""^16.0.3"",
    ""express"": ""^4.18.2""
  },
  ""devDependencies"": {
    ""nodemon"": ""^3.0.1""
  }
}
"@ | Out-File -Encoding UTF8 "$projectFolder\package.json"

# 4. Create server.js
@"
const express = require('express');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(express.json());

const consumerKey = process.env.MPESA_CONSUMER_KEY;
const consumerSecret = process.env.MPESA_CONSUMER_SECRET;
const shortCode = '303030';
const passkey = process.env.MPESA_PASSKEY;

const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString('base64');

async function getToken() {
    const url = 'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials';
    const { data } = await axios.get(url, { headers: { Authorization: `Basic ${auth}` } });
    return data.access_token;
}

app.post('/stkpush', async (req, res) => {
    try {
        const token = await getToken();
        const timestamp = new Date().toISOString().replace(/[-:TZ.]/g,'').slice(0,14);
        const password = Buffer.from(`${shortCode}${passkey}${timestamp}`).toString('base64');
        const { phone, amount } = req.body;

        const response = await axios.post(
            'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest',
            {
                BusinessShortCode: shortCode,
                Password: password,
                Timestamp: timestamp,
                TransactionType: 'CustomerPayBillOnline',
                Amount: amount,
                PartyA: phone,
                PartyB: shortCode,
                PhoneNumber: phone,
                CallBackURL: 'https://your-vercel-app.vercel.app/callback',
                AccountReference: 'Test123',
                TransactionDesc: 'Payment'
            },
            { headers: { Authorization: `Bearer ${token}` } }
        );

        res.json(response.data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(3000, () => console.log('Server running on port 3000'));
"@ | Out-File -Encoding UTF8 "$projectFolder\server.js"

# 5. Create vercel.json
@"
{
  ""version"": 2,
  ""builds"": [
    { ""src"": ""server.js"", ""use"": ""@vercel/node"" }
  ],
  ""routes"": [
    { ""src"": ""/(.*)"", ""dest"": ""server.js"" }
  ]
}
"@ | Out-File -Encoding UTF8 "$projectFolder\vercel.json"

# 6. Create README.md
@"
# M-Pesa Vercel Project

This project integrates M-Pesa Daraja API with an Express server, deployable on Vercel.

## Setup
1. Install dependencies:
   npm install

2. Copy .env.example to .env and fill your M-Pesa credentials.

3. Run locally:
   npm run dev

4. Deploy to Vercel:
   vercel
"@ | Out-File -Encoding UTF8 "$projectFolder\README.md"

# 7. Create .env.example
@"
MPESA_CONSUMER_KEY=your_key
MPESA_CONSUMER_SECRET=your_secret
MPESA_SHORTCODE=303030
MPESA_PASSKEY=your_passkey
MPESA_ENV=sandbox
"@ | Out-File -Encoding UTF8 "$projectFolder\.env.example"

# 8. Initialize Git and commit
Set-Location $projectFolder
git init -b main
git add .
git commit -m "Initial commit with M-Pesa integration"

# 9. Go back and compress
Set-Location ..
Compress-Archive -Path $projectFolder -DestinationPath $zipName -Force

# 10. Split using 7-Zip
& "$sevenZipPath" a -v$splitSize $splitPrefix $zipName

Write-Host "✅ Project zipped and split into parts (<20MB each)!"
