class_name AssetDef
extends Resource
## כרטיס אסט אחד: כל מה שהמנוע צריך לדעת כדי לטעון ולהציג אובייקט
## מתוך בנק האסטים.

## מזהה ייחודי, למשל "simpletable".
@export var id: StringName = &""
## השם שיוצג לילדים בבנק.
@export var display_name: String = ""
## הקטגוריה שאליה האסט שייך (מזהה קטגוריה, למשל "furniture").
@export var category: StringName = &""
## נתיב לקובץ המודל (.glb / .gltf / .tscn) בתוך הפרויקט.
@export var scene_path: String = ""
## האם ליישר את המודל אוטומטית כך שנקודת המוצא שלו תהיה בתחתית-המרכז
## של המודל. מודל שממורכז נכון בבלנדר לא זז בכלל.
@export var auto_center: bool = true
