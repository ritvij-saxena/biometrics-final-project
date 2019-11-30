import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:multi_image_picker/multi_image_picker.dart';
import 'package:path/path.dart' show join;
import 'package:path/path.dart' as prefix0;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;

const PROJECT_ID = "biometricsasservice";
const STORAGE_BUCKET = "gs://$PROJECT_ID.appspot.com";
const AUTO_ML_BUCKET = "gs://$PROJECT_ID-vcm";
const REALDB_BUCKET = "https://$PROJECT_ID.firebaseio.com/";
//const FUNCTIONS_URL = "us-central1-$PROJECT_ID.cloudfunctions.net";

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return MyHomePageState();
  }
}

class MyHomePageState extends State<MyHomePage> {
  LocalAuthentication authentication = LocalAuthentication();
  bool _canCheckBiometrics;
  String _authorized = "Not Authorized";
  List<BiometricType> _availableBiometrics;
  dynamic dialogAuth = [false, ''];
  String nameHomePage;

//  int id;

  Future<void> checkBiometrics() async {
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await authentication.canCheckBiometrics;
    } on PlatformException catch (e) {
      print(e);
    }

    if (!mounted) return;

    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });

    print(_canCheckBiometrics);
  }

  Future<void> getAvailableBiometrics() async {
    List<BiometricType> availableBiometrics;
    try {
      availableBiometrics = await authentication.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print(e);
    }

    if (!mounted) return;

    setState(() {
      _availableBiometrics = availableBiometrics;
    });

    print(_availableBiometrics);
  }

  Future<void> performFingerprintAuthentication() async {
    await checkBiometrics();
    await getAvailableBiometrics();
    bool authenticated;
    try {
      authenticated = await authentication.authenticateWithBiometrics(
          localizedReason: "Step 2 for required task",
          useErrorDialogs: true,
          stickyAuth: true);
    } on PlatformException catch (e) {
      print(e);
    }

    if (!mounted) return;

    setState(() {
      _authorized = authenticated ? "Authorized" : "Not Authorized";
    });

    print(_authorized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Biometric Final Project'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
                hoverColor: Colors.greenAccent,
                color: Colors.green,
                child: Text('Enroll'),
                onPressed: () {
                  Fluttertoast.showToast(
                    msg: "Entrollment Procedure",
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => CameraWidget()));
                }),
            RaisedButton(
                hoverColor: Colors.blueGrey[100],
                color: Colors.blueGrey[200],
                child: Text('Perform Recognition'),
                onPressed: () async {
                  Fluttertoast.showToast(
                    msg: "Recognition Procedure",
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  dialogAuth = await authDialog(context);
                  print('dialogauth ' + dialogAuth[0].toString());
                  print('dailogauth vals' + dialogAuth.toString());
                  if (dialogAuth[0]) {
                    await performFingerprintAuthentication();
                    if (_authorized == "Authorized") {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  FaceRecognitionPage(dialogAuth[1])));
                    } else {
                      Fluttertoast.showToast(
                        msg:
                        "Fingerprint not registered on device or Wrong Fingerprint",
                        toastLength: Toast.LENGTH_SHORT,
                      );
                    }
                  } else {
                    Fluttertoast.showToast(
                      msg: "Wrong PIN or No Pin entered",
                      toastLength: Toast.LENGTH_SHORT,
                    );
                  }
                })
          ],
        ),
      ),
    );
  }
}

Future /*<bool>*/ authDialog(BuildContext context) {
  bool result = false;
  var key = GlobalKey<FormState>();
  String name;
  int pin;
  return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Identify Yourself (Step 1)'),
          content: Form(
            key: key,
            child: Container(
              height: 150.0,
              child: Column(
                children: <Widget>[
                  TextFormField(
                      validator: (value) {
                        if (value == null) {
                          return 'Enter the Correct Name';
                        }
                        return null;
                      },
                      onSaved: (value) => name = value,
                      decoration: InputDecoration(
                          labelText: 'Name', hintText: "Enter Your Name")),
                  SizedBox(
                    height: 5.0,
                  ),
                  TextFormField(
                    obscureText: true,
                    validator: (value) {
                      if (value == null) {
                        return 'Enter the Correct Pin';
                      }
                      return null;
                    },
                    onSaved: (value) => pin = int.parse(value),
                    decoration: InputDecoration(
                        labelText: 'Pin Number', hintText: "Enter Your Pin"),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            Center(
              child: RaisedButton(
                color: Colors.green,
                child: Text('Submit'),
                onPressed: () async {
                  if (key.currentState.validate()) {
                    key.currentState.save();
                    int tempPin;
                    await FirebaseDatabase.instance
                        .reference()
                        .child(name)
                        .once()
                        .then((DataSnapshot snapshot) {
                      Map<dynamic, dynamic> map = snapshot.value;
                      map.forEach((k, v) {
                        tempPin = v;
                      });
                    });

//                    print('name: '+ name);
//                    print('pin '+ pin.toString());
                    if (pin == tempPin) {
                      result = true;
                    }
                  }
                  Navigator.of(context).pop([result, name]);
                },
              ),
            )
          ],
        );
      });
}

//---------------------------------------------------------------------------------------------------------------------------------
// Camera Widget
class CameraWidget extends StatefulWidget {
  @override
  CameraState createState() => CameraState();
}

class CameraState extends State<CameraWidget> {
  Future<void> _initializeControllerFuture;
  List<CameraDescription> cameras;
  CameraController controller;
  bool isReady = false;
  String currentPhotoPath;
  List imageList;
  String _error;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = setupCameras();
  }

  Future<void> setupCameras() async {
    try {
      cameras = await availableCameras();
      controller = CameraController(cameras[1],
          ResolutionPreset.high); //change to front facing only; //changed.
      await controller.initialize();
    } on CameraException catch (_) {
      setState(() {
        isReady = false;
      });
    }
    setState(() {
      isReady = true;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> savePhoto(String path) async {
    GallerySaver.saveImage(path);
  }

  Future<void> loadImages() async {
    setState(() {
      imageList = List();
    });

    List resultList = List();
    String error = 'No Error Dectected';
    try {
      resultList = await MultiImagePicker.pickImages(maxImages: 300);
    } on PlatformException catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    setState(() {
      imageList = resultList;
      _error = error;
    });
    print(_error == null ? "something went wrong" : _error);
    print(imageList);
  }

  Widget build(BuildContext context) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Stack(
                  alignment: AlignmentDirectional.bottomCenter,
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio,
                                child: CameraPreview(controller)),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Expanded(
                          child: RaisedButton(
                            color: Colors.blue,
                            child: Icon(Icons.camera_alt),
                            onPressed: () async {
                              Fluttertoast.showToast(
                                msg: "Photo Clicked",
                                toastLength: Toast.LENGTH_SHORT,
                              );
                              try {
                                await _initializeControllerFuture;
                                final path = join(
                                  (await getApplicationDocumentsDirectory())
                                      .path,
                                  '${DateTime.now().toString().replaceAll(
                                      new RegExp(r"\s+\b|\b\s"), "")}.png',
                                );
                                currentPhotoPath = path;
                                await controller.takePicture(path);
                                await savePhoto(path);
                              } catch (e) {
                                print(e);
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 5.0,
                        ),
                        Expanded(
                          child: RaisedButton(
                            color: Colors.blue,
                            child: Text('View Previous Photo'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DisplayPictureScreen(
                                          imagePath: currentPhotoPath),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: 5.0,
                        ),
                        Expanded(
                          child: RaisedButton(
                            color: Colors.blue,
                            child: Text('Upload and Train'),
                            onPressed: () async {
                              Fluttertoast.showToast(
                                msg: "Upload to cloud and train the model",
                                toastLength: Toast.LENGTH_SHORT,
                              );
                              await loadImages();
                              if (imageList != null && imageList.length > 0) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            ImagesForTraining(
                                                imageList: imageList)));
                              }
                            },
                          ),
                        )
                      ],
                    )
                  ]);
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ));
  }
}

//---------------------------------------------------------------------------------------------------------------------------------
// Face Recognition Widget
class FaceRecognitionPage extends StatefulWidget {
  final String name;

  FaceRecognitionPage(this.name);


  @override
  _FaceRecognitionPageState createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  File image;

  getImageAndPredict() async {
//    var imageFromCamera = await MultiImagePicker.pickImages(maxImages: 1);
    var imageFromCamera = await ImagePicker.pickImage(
        source: ImageSource.camera);
    if (imageFromCamera == null) return;
    this.setState(() {
      image = imageFromCamera;
    });
    predictOnImage(image);
  }

  predictOnImage(File path) async {
    FirebaseStorage firebaseStorage = FirebaseStorage(storageBucket: STORAGE_BUCKET);
    StorageReference storageReference = firebaseStorage
        .ref()
        .child("test");
    StorageUploadTask uploadTask =
    storageReference.putFile(path);
    StorageTaskSnapshot downloadUrl = (await uploadTask.onComplete);
    String url = (await downloadUrl.ref.getDownloadURL());
    print(url);

//    String res = await Tflite.loadModel(
//        model: "assets/model.tflite",
//        labels: "assets/dict.txt",
//        numThreads: 2 // defaults to 1
//    );
//    print('Res: '+res);
//    img.Image image = img.decodeImage(File(path.path).readAsBytesSync());
//    var recognitions = await Tflite.runModelOnBinary(binary: imageToByteListFloat32(image, 224, 127.5, 127.5));
//    await Tflite.close();
//    print(recognitions);
  }

//  Uint8List imageToByteListFloat32(img.Image image, int inputSize, double mean, double std) {
//    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
//    var buffer = Float32List.view(convertedBytes.buffer);
//    int pixelIndex = 0;
//    for (var i = 0; i < inputSize; i++) {
//      for (var j = 0; j < inputSize; j++) {
//        var pixel = image.getPixel(j, i);
//        buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
//        buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
//        buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
//      }
//    }
//    return convertedBytes.buffer.asUint8List();
//  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RaisedButton(
                color: Colors.green,
                child: Text('Start'),
                onPressed: () async {
                  Fluttertoast.showToast(
                    msg: "Final Step 3 of 3 => Face Recognition",
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  getImageAndPredict();
                },
              )
            ],
          ),
        )
    );
  }


}

//---------------------------------------------------------------------------------------------------------------------------------
// Image Display Widget

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  DisplayPictureScreen({this.imagePath});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
          child: Center(
              child: imagePath != null
                  ? Image.file(File(imagePath))
                  : Container(
                child: Text(
                    'Image Path not Avaiable, Image not taken or see gallery manually'),
              ))),
    );
  }
}

//---------------------------------------------------------------------------------------------------------------------------------
// Images For Training Widget

class ImagesForTraining extends StatefulWidget {
  final List imageList;

  ImagesForTraining({this.imageList});

  @override
  State<StatefulWidget> createState() {
    return ImagesForTrainingState();
  }
}

class ImagesForTrainingState extends State<ImagesForTraining> {
  List paths = List();
  final key = GlobalKey<FormState>();
  List<String> urls = List();
  String dataSetName;

  loadImagePaths(Asset x) async {
    return x.filePath;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    print(widget.imageList.length);
    return Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.file_upload),
              onPressed: () {
                Fluttertoast.showToast(
                  msg: "Uploading to cloud for train the model",
                  toastLength: Toast.LENGTH_SHORT,
                );
                submit();
              },
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              //alignment: AlignmentDirectional.bottomCenter,
              children: <Widget>[
                Form(
                  key: key,
                  child: TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Dataset Name', hintText: 'Dataset Name'),
                    validator: (input) {
                      if (input.isEmpty || input == null) {
                        return 'String is empty';
                      }
                      return null;
                    },
                    onSaved: (input) => dataSetName = input,
                  ),
                ),
                SizedBox(
                  height: 10.0,
                ),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 4.0,
                  crossAxisSpacing: 6.0,
                  children: List.generate(paths.length, (index) {
                    return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                        ),
                        child: Image.file(File(paths[index].toString())));
                  }),
                ),
              ],
            ),
          ),
        ));
  }

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.imageList.length; i++) {
      Asset asset = widget.imageList[i];
      loadImagePaths(asset).then((result) {
        print('Result' + result);
        setState(() {
          paths.add(result);
        });
      });
    }
  }

  void submit() async {
    if (key.currentState.validate()) {
      key.currentState.save();

      /*
        * 1 -> Import images to storage
        *   1.1 -> Create data set folder
        *   1.2 -> Create /data set/data set_name folder
        *   1.3 -> Store the images under /data set_name folder
        *   1.4 -> Get stored image links (list)
        *
        * 2 -> Create data set collection
        *   2.1 -> create /collection/document/ store csv
        *
        * 3 -> Real Database
        *   3.1 -> store data set name: ID
        * */

//      var dataSplit = ['TRAIN', 'VALIDATION', 'TEST'];
//      List<List<dynamic>> csvRow = List();
      List<dynamic> csvCell = List();
      List<List<dynamic>> csvRow = List();
      for (int i = 0; i < widget.imageList.length; i++) {
        FirebaseStorage firebaseStorage =
        FirebaseStorage(storageBucket: STORAGE_BUCKET);
        FirebaseStorage autoMLBucket =
        FirebaseStorage(storageBucket: AUTO_ML_BUCKET);

        String imageName = paths[i]
            .toString()
            .split("/")[paths[i]
            .toString()
            .split("/")
            .length - 1];
        StorageReference storageReference = firebaseStorage
            .ref()
            .child("dataset")
            .child(dataSetName)
            .child(imageName);
        StorageUploadTask uploadTask =
        storageReference.putFile(File(paths[i].toString()));
        StorageTaskSnapshot downloadUrl = (await uploadTask.onComplete);
        String url = (await downloadUrl.ref.getPath());
//          String completeURL = STORAGE_BUCKET+"/"+url;
        print('URL(Storage) Is $url');

        storageReference = autoMLBucket
            .ref()
            .child("dataset")
            .child(dataSetName)
            .child(dataSetName + imageName);
        uploadTask = storageReference.putFile(File(paths[i].toString()));
        downloadUrl = (await uploadTask.onComplete);
        url = (await downloadUrl.ref.getPath());
        String completeURL = AUTO_ML_BUCKET + "/" + url;
        print('URL(AUTOML) Is $completeURL');
//        csvCell.add(completeURL);
//        csvCell.add(dataset_name);
//        csvRow.add(csvCell);
//        csvContent.add(dataSplit[new Random().nextInt(3)]);
        csvCell.add(completeURL);
        csvCell.add(dataSetName);
        csvCell.add("\r\n");
        csvRow.add(csvCell);
      }

      String csv = ListToCsvConverter().convert(csvRow,
          textEndDelimiter: "", fieldDelimiter: ",", eol: "\r\n");
      print(csv);
      var file = await writeCSV(csv);
      print(file);
      FirebaseStorage firebaseStorage =
      FirebaseStorage(storageBucket: AUTO_ML_BUCKET);
      StorageReference storageReference =
      firebaseStorage.ref().child("dataset" + ".csv");
      StorageUploadTask uploadTask = storageReference.putFile(file);
      StorageTaskSnapshot downloadUrl = (await uploadTask.onComplete);
      String url = (await downloadUrl.ref.getPath());
      Firestore.instance
          .collection("datasetCSV")
          .document("csvpath")
          .setData({'csv': "$AUTO_ML_BUCKET" + "/" + url});
      var pin = new Random().nextInt(9999);
      FirebaseDatabase.instance
          .reference()
          .child(dataSetName)
          .set({"pin": pin});
      /* [
        [Train/Test/Validation, link, labels]
        ]*/

      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Auth Data'),
              content: Text('Your Pin for access is $pin'),
              actions: <Widget>[
                RaisedButton(
                    color: Colors.green,
                    child: Text('OK'),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => MyHomePage()),
                              (Route<dynamic> route) => false);
                    })
              ],
            );
          });
//      Go back to main page.
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    if (await File('$path/datasetCSV.csv').exists() == true) {
      File('$path/datasetCSV.csv').delete(recursive: true);
    }
    return File('$path/datasetCSV.csv');
  }

  Future writeCSV(String csv) async {
    final file = await _localFile;
//    for(int i=0;i<csv.length;i++){
//      for(int j=0;j<csv[i].length;j++){

//      }
//    }
    return file.writeAsString(csv.toString());
  }
}

//---------------------------------------------------------------------------------------------------------------------------------s
