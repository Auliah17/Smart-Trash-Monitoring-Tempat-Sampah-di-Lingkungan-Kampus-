const express = require('express');
const app = express();

app.use(express.json());

// In-memory database (tanpa MySQL)
let dataStore = [];
let nextId = 1;

// GET /data - Ambil semua data
app.get('/data', (req, res) => {
  res.status(200).json(dataStore);
});

// GET /data/:id - Ambil data berdasarkan ID
app.get('/data/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const item = dataStore.find(d => d.id === id);
  if (!item) {
    return res.status(404).json({ error: 'Data not found' });
  }
  res.status(200).json(item);
});

// POST /data - Tambah data baru
app.post('/data', (req, res) => {
  const { name, value } = req.body;
  
  // 🔴 INI YANG AKAN DIUBAH UNTUK SIMULASI REGRESI 🔴
if (!name || value === undefined) {
  return res.status(400).json({ error: 'Name and value are required' });
}
  const newItem = { id: nextId++, name, value };
  dataStore.push(newItem);
  res.status(201).json(newItem);
});

// PUT /data/:id - Update data
app.put('/data/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const { name, value } = req.body;
  const item = dataStore.find(d => d.id === id);
  if (!item) {
    return res.status(404).json({ error: 'Data not found' });
  }
  if (name !== undefined) item.name = name;
  if (value !== undefined) item.value = value;
  res.status(200).json(item);
});

// DELETE /data/:id - Hapus data
app.delete('/data/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const index = dataStore.findIndex(d => d.id === id);
  if (index === -1) {
    return res.status(404).json({ error: 'Data not found' });
  }
  dataStore.splice(index, 1);
  res.status(204).send();
});

module.exports = app;