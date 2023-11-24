import tensorflow as tf
from tensorflow.keras.models import load_model
import tensorflowjs as tfjs

h5_file_path = "CNN_Models_final/model.h5"
output_json_model_dir = "CNN_Models_final/"

model = load_model(h5_file_path)

tfjs.converters.save_keras_model(model, output_json_model_dir)
