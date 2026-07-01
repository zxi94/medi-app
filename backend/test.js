const express = require('express');
const app = express();
app.get('/', (req, res) => res.send('ok'));
app.listen(5002, () => console.log('listening on 5002'));
