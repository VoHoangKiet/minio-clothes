# Trình quản lý Triển khai MinIO trên Docker (MinIO Docker Deployment Manager)

Dự án này cung cấp một cấu hình hoàn chỉnh để triển khai, cấu hình và quản lý **MinIO Object Storage** (lưu trữ đối tượng tương thích hoàn toàn với Amazon S3) chạy trên Docker Compose. Nó đi kèm các script tự động hóa khởi tạo bucket và các tác vụ quản trị thường nhật như backup/restore dữ liệu.

---

## 🌟 Tính năng nổi bật

- 🐳 **Đóng gói hoàn chỉnh**: Khởi chạy MinIO Server và MinIO Console UI chỉ với một câu lệnh.
- ⚙️ **Tự động cấu hình (Auto-provisioning)**: Tự động khởi tạo danh sách bucket mặc định và thiết lập chính sách (public/private policy) ngay khi khởi động thông qua sidecar container `mc` (MinIO Client).
- 🔒 **Quản lý cấu hình qua `.env`**: Dễ dàng tùy chỉnh cổng kết nối, tài khoản admin, vị trí lưu trữ và các bucket mà không cần thay đổi file `docker-compose.yml`.
- 🛠️ **Hỗ trợ đa nền tảng**: Tích hợp sẵn script quản lý bằng PowerShell (`manage.ps1`) cho Windows và Bash (`manage.sh`) cho Linux/WSL/macOS.
- 📦 **Backup & Restore**: Tích hợp cơ chế sao lưu dữ liệu ra file nén zip/tar.gz và phục hồi dữ liệu nhanh chóng chỉ với một lệnh.

---

## 📁 Cấu trúc thư mục dự án

```text
PPR501/
└── minio/
    ├── docker-compose.yml      # Cấu hình Docker Compose (MinIO Server & MC Client)
    ├── .env.example            # Bản mẫu cấu hình môi trường
    ├── .env                    # Cấu hình thực tế (Đã có sẵn mật khẩu mặc định)
    ├── .gitignore              # Định nghĩa các thư mục bỏ qua (data, backups, .env)
    ├── README.md               # Hướng dẫn sử dụng chi tiết (tài liệu này)
    └── scripts/
        ├── manage.ps1          # Script quản lý trên Windows (PowerShell)
        └── manage.sh           # Script quản lý trên Linux/macOS/WSL (Bash)
```

---

## 🛠️ Yêu cầu hệ thống

Trước khi bắt đầu, hãy đảm bảo máy tính của bạn đã cài đặt:
1. **Docker Engine** (phiên bản 20.10+)
2. **Docker Compose** (phiên bản 2.0+)
*(Khuyên dùng **Docker Desktop** cho cả Windows và macOS).*

---

## 🚀 Hướng dẫn nhanh (Quick Start)

### Bước 1: Di chuyển vào thư mục dự án
Mở terminal/PowerShell tại thư mục gốc `PPR501` và chuyển hướng vào thư mục `minio`:
```bash
cd minio
```

### Bước 2: Xem qua cấu hình `.env`
Dự án đã chuẩn bị sẵn file `.env` được cấu hình mặc định hoạt động ngay lập tức:
```env
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadminpassword
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_VOLUMES=./data
MINIO_DEFAULT_BUCKETS=public-bucket,private-bucket,temp-bucket
MINIO_PUBLIC_BUCKETS=public-bucket
```

### Bước 3: Khởi động hệ thống

#### 👉 Trên Windows (PowerShell):
Chạy lệnh khởi động:
```powershell
.\scripts\manage.ps1 up
```
*(Nếu gặp lỗi phân quyền thực thi script, hãy chạy `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process` rồi thực hiện lại).*

#### 👉 Trên Linux / WSL / macOS (Bash):
Cấp quyền thực thi và chạy script:
```bash
chmod +x scripts/manage.sh
./scripts/manage.sh up
```

### Bước 3: Truy cập hệ thống
- **API Endpoint** (Sử dụng cho Code/SDK): [http://localhost:9000](http://localhost:9000)
- **Console UI** (Trình quản lý giao diện trực quan): [http://localhost:9001](http://localhost:9001)
- **Tài khoản**: `minioadmin`
- **Mật khẩu**: `minioadminpassword`

Sau khi khởi động, bạn sẽ thấy 3 bucket tự động được tạo: `public-bucket`, `private-bucket`, và `temp-bucket`. Trong đó, `public-bucket` sẽ được mở quyền download công khai (public read).

---

## 🛠️ Hướng dẫn quản trị chi tiết (CLI Reference)

Cả hai script quản trị đều hỗ trợ các câu lệnh sau với chức năng tương đương:

| Lệnh (Action) | PowerShell (Windows) | Bash (Linux/macOS) | Mô tả |
| :--- | :--- | :--- | :--- |
| **Khởi động** | `.\scripts\manage.ps1 up` | `./scripts/manage.sh up` | Khởi chạy dịch vụ ở chế độ chạy ngầm (background) |
| **Dừng** | `.\scripts\manage.ps1 down` | `./scripts/manage.sh down` | Dừng và xóa toàn bộ container |
| **Restart** | `.\scripts\manage.ps1 restart` | `./scripts/manage.sh restart` | Khởi động lại dịch vụ |
| **Logs** | `.\scripts\manage.ps1 logs` | `./scripts/manage.sh logs` | Theo dõi logs của container trong thời gian thực |
| **Trạng thái** | `.\scripts\manage.ps1 status` | `./scripts/manage.sh status` | Xem trạng thái các container |
| **Backup** | `.\scripts\manage.ps1 backup` | `./scripts/manage.sh backup` | Tạm dừng ghi dữ liệu và nén toàn bộ data thành file nén trong thư mục `backups/` |
| **Restore** | `.\scripts\manage.ps1 restore` | `./scripts/manage.sh restore` | Khôi phục dữ liệu từ file backup (mặc định chọn file mới nhất) |

### Ví dụ về Backup & Restore:
1. **Tạo bản sao lưu**:
   ```powershell
   # Windows
   .\scripts\manage.ps1 backup
   ```
   *Một file `backups/minio-backup-YYYYMMDD-HHMMSS.zip` sẽ được tạo ra.*

2. **Khôi phục dữ liệu**:
   ```powershell
   # Khôi phục từ bản sao lưu gần nhất:
   .\scripts\manage.ps1 restore

   # Hoặc chỉ định một file cụ thể:
   .\scripts\manage.ps1 restore .\backups\minio-backup-20260609-000000.zip
   ```

---

## 💻 Hướng dẫn kết nối bằng Code (SDK Code Examples)

### 1. Node.js (Sử dụng `@aws-sdk/client-s3`)

Cài đặt thư viện:
```bash
npm install @aws-sdk/client-s3
```

Đoạn mã kết nối và liệt kê file:
```javascript
const { S3Client, ListObjectsV2Command } = require("@aws-sdk/client-s3");

const s3Client = new S3Client({
  endpoint: "http://localhost:9000",
  region: "us-east-1",
  credentials: {
    accessKeyId: "minioadmin",
    secretAccessKey: "minioadminpassword",
  },
  forcePathStyle: true,
});

async function listFiles(bucketName) {
  try {
    const command = new ListObjectsV2Command({ Bucket: bucketName });
    const response = await s3Client.send(command);
    console.log("Danh sách files:", response.Contents || []);
  } catch (error) {
    console.error("Lỗi kết nối MinIO:", error);
  }
}

listFiles("public-bucket");
```

### 2. Python (Sử dụng `boto3`)

Cài đặt thư viện:
```bash
pip install boto3
```

Đoạn mã kết nối và upload file:
```python
import boto3
from botocore.client import Config

# Khởi tạo S3 Client kết nối tới MinIO
s3 = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadminpassword',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# Upload 1 file lên bucket
try:
    s3.upload_file(
        Filename='my_document.pdf',
        Bucket='public-bucket',
        Key='uploaded_document.pdf'
    )
    print("Upload file thành công lên public-bucket!")
except Exception as e:
    print(f"Lỗi khi upload: {e}")
```

---

## 🔒 Khuyến nghị Bảo mật khi lên Production
Khi deploy môi trường Production thực tế, hãy lưu ý:
1. Thay đổi giá trị `MINIO_ROOT_USER` và `MINIO_ROOT_PASSWORD` trong file `.env` thành chuỗi ký tự bảo mật và phức tạp hơn.
2. Tránh commit file `.env` thực tế lên Git repo bằng cách đưa nó vào `.gitignore` (mặc định đã được cấu hình).
3. Đảm bảo thay đổi `MINIO_VOLUMES` sang đường dẫn lưu trữ an toàn hoặc sử dụng Docker Volume Driver ngoài để đảm bảo an toàn phần cứng.
4. Cấu hình HTTPS (SSL) bằng cách sử dụng các Reverse Proxy như **Nginx**, **Traefik** hoặc **Caddy** trước khi công khai cổng API/Console ra Internet.
#   m i n i o - c l o t h e s  
 