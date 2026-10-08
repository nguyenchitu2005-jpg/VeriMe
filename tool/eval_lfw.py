"""Đo model nhận diện khuôn mặt trên bộ ảnh LFW, mô phỏng đúng quy trình của app.

- Đăng ký: trung bình vector của 5 ảnh, chuẩn hoá L2.
- Đăng nhập: 2 ảnh, lấy ảnh tốt nhất (khoảng cách nhỏ nhất) so với ngưỡng.
- Người lạ: 10 người ngẫu nhiên, và 10 người GIỐNG NHẤT (mẫu gần nhất) với mỗi người.

Cài đặt (Windows dùng Python 3.12; đặt venv ở đường dẫn ngắn để tránh lỗi đường dẫn dài):
    py -3.12 -m venv D:\\tfe
    D:\\tfe\\Scripts\\python -m pip install tensorflow numpy pillow scikit-learn
Chạy từ thư mục gốc project (lần đầu tự tải LFW ~200 MB):
    D:\\tfe\\Scripts\\python tool/eval_lfw.py [đường_dẫn_model.tflite] [cách_chuẩn_hoá]
    cách_chuẩn_hoá: "standardize" (FaceNet, mặc định) hoặc "128" (MobileFaceNet: (x-128)/128)
"""
import sys

import numpy as np
import tensorflow as tf
from PIL import Image
from sklearn.datasets import fetch_lfw_people

MODEL = sys.argv[1] if len(sys.argv) > 1 else "assets/models/facenet_512.tflite"
NORM = sys.argv[2] if len(sys.argv) > 2 else "standardize"
CROP = 150  # vùng cắt (px) quanh khuôn mặt trong ảnh LFW 250x250 (mặt rộng ~110px) ≈ lề 1.3

full = fetch_lfw_people(min_faces_per_person=8, color=True, resize=1.0,
                        slice_=(slice(0, 250), slice(0, 250)))
imgs = full.images * (255.0 if full.images.max() <= 1.0 else 1.0)
people = {}
for i, label in enumerate(full.target):
    people.setdefault(label, []).append(i)
ids = list(people)

it = tf.lite.Interpreter(model_path=MODEL)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]
size = inp["shape"][1]


def embed(im):
    half = CROP // 2
    crop = im[130 - half:130 + half, 125 - half:125 + half].astype(np.uint8)
    x = np.asarray(Image.fromarray(crop).resize((size, size), Image.BILINEAR), np.float32)
    if NORM == "128":
        x = (x - 128.0) / 128.0
    else:
        x = (x - x.mean()) / max(x.std(), 1.0 / np.sqrt(x.size))
    it.set_tensor(inp["index"], x[None].astype(np.float32))
    it.invoke()
    v = it.get_tensor(out["index"])[0]
    return v / np.linalg.norm(v)


emb = np.stack([embed(im) for im in imgs])
rng = np.random.default_rng(1)
gen, rnd, hard = [], [], []
for _ in range(5):
    tpl, prb = {}, {}
    for p in ids:
        idx = rng.permutation(people[p])
        t = emb[idx[:5]].mean(0)
        tpl[p] = t / np.linalg.norm(t)
        prb[p] = emb[idx[5:7]]
    T = np.stack([tpl[p] for p in ids])
    td = np.linalg.norm(T[:, None] - T[None], axis=2)
    for a, p in enumerate(ids):
        gen.append(np.linalg.norm(prb[p] - tpl[p], axis=1).min())
        for q in rng.choice([x for x in ids if x != p], 10, replace=False):
            rnd.append(np.linalg.norm(prb[q] - tpl[p], axis=1).min())
        for j in [j for j in np.argsort(td[a]) if ids[j] != p][:10]:
            hard.append(np.linalg.norm(prb[ids[j]] - tpl[p], axis=1).min())
gen, rnd, hard = map(np.array, (gen, rnd, hard))

print(f"{MODEL}: {len(imgs)} ảnh, {len(ids)} người; vào {size}px, {out['shape'][-1]} chiều")
for t in np.arange(0.50, 1.001, 0.05):
    print(f"  ngưỡng {t:.2f}: chính chủ được nhận {np.mean(gen < t) * 100:5.1f}% | "
          f"người lạ lọt {np.mean(rnd < t) * 100:5.2f}% | người giống nhất lọt {np.mean(hard < t) * 100:5.2f}%")
