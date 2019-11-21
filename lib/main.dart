import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:multi_image_picker/multi_image_picker.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  bool dialogAuth = false;
  String id = "1234";

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
                child: Text('Perform Recognition'),
                onPressed: () async {
                  Fluttertoast.showToast(
                    msg: "Recognition Procedure",
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  dialogAuth = await authDialog(context, id);
                  print('dialogauth ' + dialogAuth.toString());
                  if (dialogAuth) {
                    await performFingerprintAuthentication();
                    if (_authorized == "Authorized") {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => FaceRecognitionPage()));
                    }
                  }
                })
          ],
        ),
      ),
    );
  }
}

Future<bool> authDialog(BuildContext context, String id)  {
  TextEditingController controller = TextEditingController();
  bool result = false;
  return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Identify Yourself (Step 1)'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
                labelText: 'Identification Number', hintText: "Enter Your ID"),
          ),
          actions: <Widget>[
            RaisedButton(
              color: Colors.green,
              child: Text('Submit'),
              onPressed: () {
                  if(controller.text == id){
                    result = true;
                  }
                  Navigator.of(context).pop(result);
              },
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
      controller = CameraController(
          cameras[0], ResolutionPreset.high); //change to front facing only
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
                                  '${DateTime.now().toString().replaceAll(new RegExp(r"\s+\b|\b\s"), "")}.png',
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
                                  builder: (context) => DisplayPictureScreen(
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
                                        builder: (context) => ImagesForTraining(
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
class FaceRecognitionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
        body: Center(
            child: Container(
      child: Text('Face Recognition'),
    )));
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
    // TODO: implement createState
    return ImagesForTrainingState();
  }
}

class ImagesForTrainingState extends State<ImagesForTraining> {
  List paths = List();
  final key = GlobalKey<FormState>();

  //List tempList = List();
  String dataset_name;

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
        body: SingleChildScrollView(
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
                    } else {
                      return null;
                    }
                  },
                  onSaved: (input) => dataset_name = input,
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
                  return Image.file(File(paths[index].toString()));
                }),
              ),
            ],
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

  void submit() {
    if (key.currentState.validate()) {
      key.currentState.save();
      print(dataset_name);
    }
  }
}

//---------------------------------------------------------------------------------------------------------------------------------s
