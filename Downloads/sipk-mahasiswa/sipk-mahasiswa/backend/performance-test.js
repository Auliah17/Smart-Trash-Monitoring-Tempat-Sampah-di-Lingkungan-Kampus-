import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    // Skenario 1: Load Test (50 VU konstan selama 1 menit)
    load_test: {
      executor: 'constant-vus',
      vus: 50,
      duration: '1m',
      exec: 'runTest', 
    },
    // Skenario 2: Stress Test (Ramp-up bertahap hingga puncak 200 VU)
    stress_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 100 }, // Naik ke 100 pengguna dalam 30 detik
        { duration: '30s', target: 200 }, // Naik lagi ke 200 pengguna (Puncak)
        { duration: '30s', target: 200 }, // Pertahankan di 200 pengguna selama 30 detik
        { duration: '30s', target: 0 },   // Turun kembali ke 0 pengguna
      ],
      exec: 'runTest',
      startTime: '1m10s', // Dijalankan otomatis 10 detik setelah Load Test selesai
    },
  },
  // Batasan performa (Thresholds) untuk laporan
  thresholds: {
    http_req_failed: ['rate<0.01'],   // Error rate harus di bawah 1% (0.01)
    http_req_duration: ['p(95)<2000'], // Response Time P95 harus di bawah 2 detik (2000ms)
  },
};

// Fungsi utama yang akan dijalankan oleh Virtual Users (VU)
export function runTest() {
  
  // URL sudah diubah untuk menguji endpoint router kegiatan kelompok Anda
  const url = 'http://localhost:5000/kegiatan';
  
  const res = http.get(url);

  // Memastikan response status yang kembali adalah 200 OK
  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  // Jeda 1 detik antar request agar menyerupai perilaku asli manusia
  sleep(1); 
}