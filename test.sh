#/bin/bash

curl -i -X POST https://keystone.rumble.cloud/v3/auth/tokens \
-H "Content-Type: application/json" \
-d '{
    "auth": {
        "identity": {
            "methods": ["application_credential"],
            "application_credential": {
                "id": "a18f623f2cb4495e8440d9d5267c2578",
                "secret": "If6bLp19BuZJ8KEwZT_J7hGSFRIrwXe9qVyFKTQoqrYrF7BcZXtufYgr3_yPNRqArsh2ZEmCXX1ayaroyYNOKA"
            }
        }
    }
}'
