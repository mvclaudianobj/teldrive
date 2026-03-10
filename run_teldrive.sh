#!/bin/bash
/usr/local/go/bin/go run main.go run \
  --tg-app-id=466395 \
  --tg-app-hash=26a28aac442406c3b03e0e3527eb8fbb \
  --tg-uploads-encryption-key=f42de1a7b7536eded4aa53abcc7dba93856170bc8a19c8878b1e180619b8d0de \
  --jwt-secret=3b614ba311e8683f4822276a4d85d6beacc1ef1b86ce82f0fe26 \
  --db-data-source=postgres://teldrive:secret@postgres_db/postgres \
  --server-port=3940