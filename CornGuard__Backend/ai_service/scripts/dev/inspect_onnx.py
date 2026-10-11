
import onnxruntime as ort

model_path = "models/best.onnx"

session = ort.InferenceSession(
    model_path,
    providers=["CPUExecutionProvider"],
)

print("=== INPUT ===")
for item in session.get_inputs():
    print("Name:", item.name)
    print("Shape:", item.shape)
    print("Type:", item.type)

print("\n=== OUTPUT ===")
for item in session.get_outputs():
    print("Name:", item.name)
    print("Shape:", item.shape)
    print("Type:", item.type)
