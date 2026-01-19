import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'dart:math'; // REMOVIDO: Não é mais utilizado
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MecaHeroApp());
}

class MecaHeroApp extends StatelessWidget {
  const MecaHeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MecaHero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.grey[900],
        ),
      ),
      home: const GameScreen(),
    );
  }
}

// --- CLASSE DE DADOS DA NOTA ---
class Note {
  final int lane;
  double y;
  bool hit;
  bool missed;
  final Color color;

  Note({required this.lane, required this.y, required this.color})
      : hit = false,
        missed = false;
}

// --- CLASSE PARA A MELODIA ---
class SongEvent {
  final int lane;
  final double
      time; // Tempo absoluto (timestamp) em segundos desde o início da música

  SongEvent(this.lane, this.time);

  // Converte para Mapa (JSON) para salvar
  Map<String, dynamic> toJson() => {
        'lane': lane,
        'time': time,
      };

  // Cria a partir de Mapa (JSON) ao carregar
  factory SongEvent.fromJson(Map<String, dynamic> json) {
    // Suporte legado para 'delay' se necessário, mas preferência por 'time'
    double val = 0.0;
    if (json.containsKey('time')) {
      val = (json['time'] as num).toDouble();
    } else if (json.containsKey('delay')) {
      val = (json['delay'] as num).toDouble();
    }

    return SongEvent(
      json['lane'] as int,
      val,
    );
  }
}

// --- TELA PRINCIPAL DO JOGO ---
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  // Audio Players (Agora são 8 canais)
  final List<AudioPlayer> _players = List.generate(8, (_) => AudioPlayer());

  // Estado do Jogo
  bool isPlaying = false;
  bool isDemoMode = false;
  bool isRecording = false;

  // Variável para corrigir o bug de múltiplas chamadas de fim de jogo
  bool _isGameOverScheduled = false;

  int score = 0;
  int combo = 0;
  int multiplier = 1;
  double speed = 200.0; // Velocidade

  // Estado Visual dos Botões (8 botões)
  List<bool> lanePressed = List.filled(8, false);

  // Sequenciador e Gravação
  List<Note> notes = [];
  int noteIndex = 0;

  // Variáveis de Tempo
  Duration _lastElapsed = Duration.zero;
  DateTime? _recordingStartTime;

  // Melodia gravada temporária
  List<SongEvent> recordedMelody = [];

  // Cores das 8 trilhas
  final List<Color> laneColors = [
    Colors.redAccent, // 0
    Colors.orangeAccent, // 1
    Colors.yellowAccent, // 2
    Colors.greenAccent, // 3
    Colors.cyanAccent, // 4
    Colors.blueAccent, // 5
    Colors.purpleAccent, // 6
    Colors.pinkAccent, // 7
  ];

  // Melodia Atual (Começa vazia)
  List<SongEvent> currentMelody = [];
  String currentSongTitle = "Nenhuma música carregada";

  double hitLineY = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_gameLoop);
    _preloadAudio();
    // Garante que as músicas padrão existam
    _ensureDefaultMelodies();
  }

  void _preloadAudio() async {
    for (var player in _players) {
      try {
        await player.setReleaseMode(ReleaseMode.stop);
      } catch (e) {
        debugPrint("Erro ao configurar áudio: $e");
      }
    }
  }

  // Cria arquivos de música padrão se não existirem
  void _ensureDefaultMelodies() async {
    final path = await _localPath();

    // Lista exata fornecida (Convertida para SongEvent)
    final Map<String, List<SongEvent>> defaultSongs = {
      "Doremifa": [
        SongEvent(0, 0.00),
        SongEvent(3, 0.30),
        SongEvent(2, 0.60),
        SongEvent(1, 0.90),
        SongEvent(0, 1.20),
        SongEvent(1, 1.50),
        SongEvent(0, 1.80),
        SongEvent(0, 2.10),
        SongEvent(0, 2.70),
        SongEvent(1, 3.00),
        SongEvent(0, 3.30),
        SongEvent(1, 3.60),
        SongEvent(2, 3.90),
        SongEvent(3, 4.20),
        SongEvent(3, 4.50),
        SongEvent(3, 4.80),
        SongEvent(0, 5.10),
        SongEvent(3, 5.40),
        SongEvent(2, 5.70),
        SongEvent(1, 6.00),
        SongEvent(0, 6.30),
        SongEvent(1, 6.60),
        SongEvent(0, 6.90),
        SongEvent(0, 7.50),
        SongEvent(1, 7.80),
        SongEvent(0, 8.10),
        SongEvent(1, 8.40),
        SongEvent(2, 8.70),
        SongEvent(3, 9.00),
        SongEvent(0, 9.30),
        SongEvent(1, 9.60),
        SongEvent(2, 9.90),
        SongEvent(3, 10.20),
        SongEvent(3, 10.50),
        SongEvent(3, 11.10),
        SongEvent(3, 11.70),
        SongEvent(3, 12.00),
        SongEvent(0, 12.60),
        SongEvent(1, 12.90),
        SongEvent(0, 13.20),
        SongEvent(1, 13.50),
        SongEvent(1, 13.80),
        SongEvent(1, 14.40),
        SongEvent(1, 15.00),
        SongEvent(1, 15.30),
        SongEvent(0, 15.60),
        SongEvent(4, 15.90),
        SongEvent(3, 16.20),
        SongEvent(2, 16.50),
        SongEvent(2, 16.80),
        SongEvent(2, 17.40),
        SongEvent(2, 18.00),
        SongEvent(2, 18.30),
        SongEvent(0, 18.60),
        SongEvent(1, 18.90),
        SongEvent(2, 19.20),
        SongEvent(3, 19.50),
        SongEvent(3, 19.80),
        SongEvent(3, 20.40),
        SongEvent(3, 21.00),
        SongEvent(3, 21.30),
        SongEvent(0, 21.60),
        SongEvent(1, 21.90),
        SongEvent(2, 22.20),
        SongEvent(3, 22.50),
        SongEvent(3, 22.80),
        SongEvent(3, 23.40),
        SongEvent(3, 24.00),
        SongEvent(3, 24.30),
        SongEvent(0, 24.60),
        SongEvent(1, 24.90),
        SongEvent(0, 25.20),
        SongEvent(1, 25.50),
        SongEvent(1, 25.80),
        SongEvent(1, 26.40),
        SongEvent(1, 27.00),
        SongEvent(1, 27.30),
        SongEvent(0, 27.60),
        SongEvent(4, 27.90),
        SongEvent(3, 28.20),
        SongEvent(2, 28.50),
        SongEvent(2, 28.80),
        SongEvent(2, 29.40),
        SongEvent(2, 30.00),
        SongEvent(2, 30.30),
        SongEvent(0, 30.60),
        SongEvent(1, 30.90),
        SongEvent(2, 31.20),
        SongEvent(3, 31.50),
        SongEvent(3, 31.80),
        SongEvent(0, 32.10),
        SongEvent(3, 32.40),
        SongEvent(2, 32.70),
        SongEvent(1, 33.00),
        SongEvent(0, 33.30),
        SongEvent(1, 33.60),
        SongEvent(0, 33.90),
        SongEvent(1, 34.20),
        SongEvent(2, 34.50),
        SongEvent(3, 34.80),
        SongEvent(3, 35.10),
        SongEvent(3, 35.40),
        SongEvent(0, 35.70),
        SongEvent(3, 36.00),
        SongEvent(2, 36.30),
        SongEvent(1, 36.60),
        SongEvent(0, 36.90),
        SongEvent(1, 37.20),
        SongEvent(0, 37.50),
        SongEvent(0, 38.10),
        SongEvent(1, 38.40),
        SongEvent(0, 38.70),
        SongEvent(1, 39.00),
        SongEvent(2, 39.30),
        SongEvent(3, 39.60),
        SongEvent(0, 39.90),
        SongEvent(1, 40.20),
        SongEvent(2, 40.50),
        SongEvent(3, 40.80),
        SongEvent(3, 41.10),
        SongEvent(3, 41.70),
        SongEvent(3, 42.30),
        SongEvent(3, 42.60),
        SongEvent(0, 42.90),
        SongEvent(1, 43.20),
        SongEvent(0, 43.50),
        SongEvent(1, 43.80),
        SongEvent(1, 44.10),
        SongEvent(1, 44.70),
        SongEvent(1, 45.30),
        SongEvent(1, 45.60),
        SongEvent(0, 45.90),
        SongEvent(4, 46.20),
        SongEvent(3, 46.50),
        SongEvent(2, 46.80),
        SongEvent(2, 47.10),
        SongEvent(2, 47.70),
        SongEvent(2, 48.30),
        SongEvent(2, 48.60),
        SongEvent(0, 48.90),
        SongEvent(1, 49.20),
        SongEvent(2, 49.50),
        SongEvent(3, 49.80),
        SongEvent(3, 50.10),
        SongEvent(3, 50.70),
        SongEvent(3, 51.30),
        SongEvent(3, 51.60),
        SongEvent(0, 51.90),
        SongEvent(1, 52.20),
        SongEvent(2, 52.50),
        SongEvent(3, 52.80),
        SongEvent(3, 53.10),
        SongEvent(3, 53.70),
        SongEvent(3, 54.30),
        SongEvent(3, 54.60),
        SongEvent(0, 54.90),
        SongEvent(1, 55.20),
        SongEvent(0, 55.50),
        SongEvent(1, 55.80),
        SongEvent(1, 56.10),
        SongEvent(1, 56.70),
        SongEvent(1, 57.30),
        SongEvent(1, 57.60),
        SongEvent(0, 57.90),
        SongEvent(4, 58.20),
        SongEvent(3, 58.50),
        SongEvent(2, 58.80),
        SongEvent(2, 59.10),
        SongEvent(2, 59.70),
        SongEvent(2, 60.30),
        SongEvent(2, 60.60),
        SongEvent(0, 60.90),
        SongEvent(1, 61.20),
        SongEvent(2, 61.50),
        SongEvent(3, 61.80),
        SongEvent(3, 62.10),
        SongEvent(3, 62.70),
        SongEvent(3, 63.30),
        SongEvent(3, 63.60),
        SongEvent(3, 63.90),
        SongEvent(3, 64.20),
      ],
      "Atirei o pau no gato": [
        SongEvent(4, 0.00),
        SongEvent(3, 0.35),
        SongEvent(2, 0.70),
        SongEvent(1, 1.05),
        SongEvent(2, 1.40),
        SongEvent(3, 1.75),
        SongEvent(4, 2.10),
        SongEvent(4, 2.45),
        SongEvent(4, 2.80),
        SongEvent(4, 3.15),
        SongEvent(5, 3.50),
        SongEvent(4, 3.85),
        SongEvent(3, 4.20),
        SongEvent(3, 4.55),
        SongEvent(3, 4.90),
        SongEvent(3, 5.25),
        SongEvent(4, 5.60),
        SongEvent(3, 5.95),
        SongEvent(2, 6.30),
        SongEvent(2, 6.65),
        SongEvent(2, 7.00),
        SongEvent(1, 7.35),
        SongEvent(0, 7.70),
        SongEvent(5, 8.05),
        SongEvent(5, 8.40),
        SongEvent(5, 8.75),
        SongEvent(6, 9.10),
        SongEvent(5, 9.45),
        SongEvent(4, 9.80),
        SongEvent(4, 10.15),
        SongEvent(4, 10.50),
        SongEvent(3, 10.85),
        SongEvent(2, 11.20),
        SongEvent(4, 11.55),
        SongEvent(3, 11.90),
        SongEvent(2, 12.25),
        SongEvent(4, 12.60),
        SongEvent(3, 12.95),
        SongEvent(2, 13.30),
        SongEvent(1, 13.65),
        SongEvent(0, 14.00),
        SongEvent(0, 14.35),
        SongEvent(0, 14.70),
        SongEvent(4, 15.75),
        SongEvent(4, 16.10),
        SongEvent(3, 16.45),
        SongEvent(2, 16.80),
        SongEvent(1, 17.15),
        SongEvent(2, 17.50),
        SongEvent(3, 17.85),
        SongEvent(4, 18.20),
        SongEvent(4, 18.55),
        SongEvent(4, 18.90),
        SongEvent(5, 19.25),
        SongEvent(4, 19.60),
        SongEvent(3, 19.95),
        SongEvent(3, 20.30),
        SongEvent(3, 20.65),
        SongEvent(4, 21.00),
        SongEvent(3, 21.35),
        SongEvent(2, 21.70),
        SongEvent(2, 22.05),
        SongEvent(2, 22.40),
        SongEvent(1, 22.75),
        SongEvent(0, 23.10),
        SongEvent(5, 23.80),
        SongEvent(5, 24.15),
        SongEvent(5, 24.50),
        SongEvent(6, 24.85),
        SongEvent(5, 25.20),
        SongEvent(4, 25.55),
        SongEvent(4, 25.90),
        SongEvent(4, 26.25),
        SongEvent(3, 26.60),
        SongEvent(2, 26.95),
        SongEvent(4, 27.30),
        SongEvent(3, 27.65),
        SongEvent(2, 28.00),
        SongEvent(4, 28.35),
        SongEvent(3, 28.70),
        SongEvent(2, 29.05),
        SongEvent(1, 29.40),
        SongEvent(0, 29.75),
        SongEvent(0, 30.10),
        SongEvent(0, 30.45),
      ]
    };

    defaultSongs.forEach((filename, events) async {
      final file = File('$path/$filename.json');
      // Tenta salvar/atualizar o arquivo sempre que inicia para garantir a versão mais recente
      try {
        String jsonStr = jsonEncode(events.map((e) => e.toJson()).toList());
        await file.writeAsString(jsonStr);
        debugPrint("Música padrão criada/atualizada: $filename");
      } catch (e) {
        debugPrint("Erro ao criar música padrão: $e");
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (var p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  // --- GERENCIAMENTO DE ARQUIVOS ---

  Future<String> _localPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> _saveRecording(String filename) async {
    try {
      final path = await _localPath();
      final file = File('$path/$filename.json');

      String jsonStr =
          jsonEncode(recordedMelody.map((e) => e.toJson()).toList());

      await file.writeAsString(jsonStr);
      debugPrint("Arquivo salvo em: ${file.path}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Melodia "$filename" salva com sucesso!')));
        setState(() {
          currentMelody = List.from(recordedMelody);
          currentSongTitle = filename;
        });
      }
    } catch (e) {
      debugPrint("Erro ao salvar: $e");
    }
  }

  Future<void> _loadMelodyFromFile(File file) async {
    try {
      String contents = await file.readAsString();
      List<dynamic> jsonList = jsonDecode(contents);

      List<SongEvent> loaded =
          jsonList.map((e) => SongEvent.fromJson(e)).toList();
      // Importante: Ordena por tempo caso os dados originais estejam fora de ordem
      loaded.sort((a, b) => a.time.compareTo(b.time));

      setState(() {
        currentMelody = loaded;
        currentSongTitle = file.uri.pathSegments.last.replaceAll('.json', '');
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Melodia carregada!')));
      }
    } catch (e) {
      debugPrint("Erro ao ler: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao carregar arquivo.')));
      }
    }
  }

  Future<void> _deleteMelodyFile(File file) async {
    try {
      await file.delete();
      if (mounted) {
        Navigator.pop(context);
        _showMelodyListDialog();
      }
    } catch (e) {
      debugPrint("Erro ao deletar: $e");
    }
  }

  void _showSaveDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Salvar Melodia",
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Nome da música",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyanAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar",
                  style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _saveRecording(nameController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text("Salvar",
                  style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showMelodyListDialog() async {
    final path = await _localPath();
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    List<FileSystemEntity> files = [];
    try {
      files = dir.listSync().where((e) => e.path.endsWith('.json')).toList();
    } catch (e) {
      debugPrint("Erro ao listar arquivos: $e");
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Minhas Melodias",
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: files.isEmpty
                ? const Center(
                    child: Text("Nenhuma melodia gravada.",
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      File file = File(files[index].path);
                      String name =
                          file.uri.pathSegments.last.replaceAll('.json', '');
                      return ListTile(
                        title: Text(name,
                            style: const TextStyle(color: Colors.white)),
                        leading: const Icon(Icons.music_note,
                            color: Colors.cyanAccent),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteMelodyFile(file),
                        ),
                        onTap: () => _loadMelodyFromFile(file),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Fechar", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- CONTROLE DE JOGO E GRAVAÇÃO ---

  void _startGame({bool demo = false, bool recording = false}) {
    if (!recording && currentMelody.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Grave ou carregue uma música primeiro!')));
      return;
    }

    setState(() {
      isDemoMode = demo;
      isRecording = recording;
      score = 0;
      combo = 0;
      multiplier = 1;
      notes.clear();
      noteIndex = 0;
      _isGameOverScheduled = false;

      _lastElapsed = Duration.zero;

      if (recording) {
        recordedMelody.clear();
        _recordingStartTime = DateTime.now();
      }

      isPlaying = true;
      lanePressed = List.filled(8, false); // 8 Notas
    });
    _ticker.start();
  }

  void _stopGame() {
    _ticker.stop();
    bool wasRecording = isRecording;

    setState(() {
      isPlaying = false;
      isRecording = false;
      lanePressed = List.filled(8, false); // 8 Notas
    });

    if (wasRecording) {
      if (recordedMelody.isNotEmpty) {
        _showSaveDialog();
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title:
            const Text('Fim da Música', style: TextStyle(color: Colors.white)),
        content: Text('Pontuação Final: $score',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame(demo: isDemoMode);
            },
            child: const Text('JOGAR NOVAMENTE',
                style: TextStyle(color: Colors.cyanAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child:
                const Text('SAIR', style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
    );
  }

  void _playNoteAndAnimate(int lane) async {
    try {
      await _players[lane].stop();
      await _players[lane].play(AssetSource('note${lane + 1}.wav'));
    } catch (e) {
      // Ignora erro
    }

    if (mounted) {
      setState(() {
        lanePressed[lane] = true;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            lanePressed[lane] = false;
          });
        }
      });
    }
  }

  // --- LOOP PRINCIPAL DO JOGO ---
  void _gameLoop(Duration elapsed) {
    if (isRecording) {
      return;
    }

    setState(() {
      double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;
      if (dt > 0.1) dt = 0.016;

      double currentTime = elapsed.inMicroseconds / 1000000.0;

      while (noteIndex < currentMelody.length) {
        if (currentMelody[noteIndex].time <= currentTime) {
          int lane = currentMelody[noteIndex].lane;
          notes.add(Note(
            lane: lane,
            y: -50,
            color: laneColors[lane],
          ));
          noteIndex++;
        } else {
          break;
        }
      }

      if (noteIndex >= currentMelody.length &&
          notes.isEmpty &&
          !_isGameOverScheduled) {
        _isGameOverScheduled = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && isPlaying) _stopGame();
        });
      }

      double moveAmount = speed * dt;

      for (var note in notes) {
        note.y += moveAmount;

        if (isDemoMode && !note.hit && !note.missed) {
          if ((note.y - hitLineY).abs() < 5.0) {
            note.hit = true;
            combo++;
            if (combo > 10) multiplier = 2;
            if (combo > 20) multiplier = 3;
            score += 100 * multiplier;
            _playNoteAndAnimate(note.lane);
          }
        }

        if (note.y > hitLineY + 100 && !note.hit && !note.missed) {
          note.missed = true;
          combo = 0;
          multiplier = 1;
        }
      }

      notes.removeWhere((n) => n.y > hitLineY + 200);
    });
  }

  void _handleInput(int laneIndex) async {
    if (isRecording) {
      _playNoteAndAnimate(laneIndex);

      if (_recordingStartTime != null) {
        Duration diff = DateTime.now().difference(_recordingStartTime!);
        double timeSeconds = diff.inMilliseconds / 1000.0;

        recordedMelody.add(SongEvent(laneIndex, timeSeconds));
      }
      return;
    }

    if (!isPlaying) return;
    if (isDemoMode) return;

    double hitWindow = 70.0;

    var candidates = notes
        .where((n) =>
            n.lane == laneIndex &&
            !n.hit &&
            !n.missed &&
            (n.y - hitLineY).abs() < hitWindow)
        .toList();

    if (candidates.isNotEmpty) {
      candidates.sort(
          (a, b) => (a.y - hitLineY).abs().compareTo((b.y - hitLineY).abs()));
      var note = candidates.first;

      _playNoteAndAnimate(laneIndex);

      setState(() {
        note.hit = true;
        combo++;
        if (combo > 10) multiplier = 2;
        if (combo > 20) multiplier = 3;
        score += 100 * multiplier;
      });
    } else {
      setState(() {
        combo = 0;
        multiplier = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    hitLineY = size.height - 150;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: GamePainter(
                notes: notes,
                laneCount: 8, // 8 Notas
                hitY: hitLineY,
                laneColors: laneColors,
              ),
            ),
          ),
          if (isPlaying)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isRecording
                              ? 'GRAVANDO...'
                              : (isDemoMode ? 'MODO DEMO' : 'PONTOS'),
                          style: TextStyle(
                              color: isRecording
                                  ? Colors.redAccent
                                  : Colors.cyanAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      if (!isRecording)
                        Text('$score',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold)),
                      if (isRecording)
                        Text('${recordedMelody.length} Notas',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (!isRecording)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('MULTIPLICADOR',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('${multiplier}x',
                            style: const TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 30,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
            ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 100,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(8, (index) {
                    // 8 Notas
                    return _buildFretButton(index, size.width);
                  }),
                ),
              ),
            ),
          ),
          if (isPlaying)
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: Icon(isRecording ? Icons.stop_circle : Icons.pause,
                    color: isRecording ? Colors.red : Colors.white, size: 40),
                onPressed: _stopGame,
              ),
            ),
          if (!isPlaying)
            Container(
              color: Colors.black87,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("MECAHERO",
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                              letterSpacing: 2)),
                      const SizedBox(height: 10),
                      const Text("Estúdio Musical",
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 10),
                      Text("Música Atual: $currentSongTitle",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, color: Colors.black),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30))),
                        onPressed: () => _startGame(demo: false),
                        label: const Text("JOGAR",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 15),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.computer, color: Colors.white),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30))),
                        onPressed: () => _startGame(demo: true),
                        label: const Text("MODO DEMO",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                      const SizedBox(height: 30),
                      const Divider(
                          color: Colors.white24, endIndent: 50, indent: 50),
                      const SizedBox(height: 10),
                      const Text("GERENCIADOR",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(20)),
                            onPressed: () => _startGame(recording: true),
                            child: const Icon(Icons.fiber_manual_record,
                                color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(20)),
                            onPressed: _showMelodyListDialog,
                            child: const Icon(Icons.folder_open,
                                color: Colors.white, size: 30),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text("Gravar Nova  |  Minhas Músicas",
                          style:
                              TextStyle(color: Colors.white30, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFretButton(int index, double screenWidth) {
    double btnWidth = (screenWidth / 8) - 4; // Ajuste para 8
    bool isPressed = lanePressed[index];

    return GestureDetector(
      onTapDown: (_) => _handleInput(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: btnWidth,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
            color: isPressed
                ? laneColors[index].withValues(alpha: 0.6)
                : laneColors[index].withValues(alpha: 0.2),
            border: Border.all(
                color: isPressed ? Colors.white : laneColors[index],
                width: isPressed ? 2.5 : 1.5),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: laneColors[index]
                      .withValues(alpha: isPressed ? 0.8 : 0.3),
                  blurRadius: isPressed ? 15 : 5,
                  spreadRadius: isPressed ? 2 : 0)
            ]),
        child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: btnWidth * 0.6,
                height: btnWidth * 0.6,
                decoration: BoxDecoration(
                    color: isPressed ? Colors.white : laneColors[index],
                    shape: BoxShape.circle),
              ),
            )),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final List<Note> notes;
  final int laneCount;
  final double hitY;
  final List<Color> laneColors;

  GamePainter({
    required this.notes,
    required this.laneCount,
    required this.hitY,
    required this.laneColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double laneWidth = size.width / laneCount;

    final paintLine = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (int i = 1; i < laneCount; i++) {
      double x = i * laneWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintLine);
    }

    final paintHitLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, hitY), Offset(size.width, hitY), paintHitLine);

    for (int i = 0; i < laneCount; i++) {
      double x = (i * laneWidth) + (laneWidth / 2);
      final paintTarget = Paint()
        ..color = laneColors[i].withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      double radius = (laneWidth / 2) - 5;
      if (radius > 28) radius = 28;
      canvas.drawCircle(Offset(x, hitY), radius, paintTarget);
    }

    for (var note in notes) {
      if (note.hit) continue;

      double x = (note.lane * laneWidth) + (laneWidth / 2);

      double radius = (laneWidth / 2) - 8;
      if (radius > 25) radius = 25;

      final paintGlow = Paint()
        ..color = note.color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(x, note.y), radius, paintGlow);

      final paintNote = Paint()..color = note.color;
      canvas.drawCircle(Offset(x, note.y), radius - 5, paintNote);

      final paintCore = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, note.y), radius - 15, paintCore);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
