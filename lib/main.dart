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
        // CORREÇÃO: Atualizado para a nova API de tema de diálogo usando DialogThemeData
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
  final double delay; // Tempo de espera desde a nota ANTERIOR (ou início)

  SongEvent(this.lane, this.delay);

  // Converte para Mapa (JSON) para salvar
  Map<String, dynamic> toJson() => {
        'lane': lane,
        'delay': delay,
      };

  // Cria a partir de Mapa (JSON) ao carregar
  factory SongEvent.fromJson(Map<String, dynamic> json) {
    return SongEvent(
      json['lane'] as int,
      (json['delay'] as num).toDouble(),
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

  // Audio Players
  final List<AudioPlayer> _players = List.generate(7, (_) => AudioPlayer());

  // Estado do Jogo
  bool isPlaying = false;
  bool isDemoMode = false;
  bool isRecording = false; // Modo de gravação

  int score = 0;
  int combo = 0;
  int multiplier = 1;
  double speed = 180.0;

  // Estado Visual dos Botões
  List<bool> lanePressed = List.filled(7, false);

  // Sequenciador e Gravação
  List<Note> notes = [];
  int noteIndex = 0;
  double timeSinceLastNote = 0.0;

  // Variáveis de Gravação
  DateTime? lastTapTime;
  List<SongEvent> recordedMelody = [];

  // Cores das 7 trilhas (Arco-íris)
  final List<Color> laneColors = [
    Colors.redAccent, // Dó
    Colors.orangeAccent, // Ré
    Colors.yellowAccent, // Mi
    Colors.greenAccent, // Fá
    Colors.cyanAccent, // Sol
    Colors.blueAccent, // Lá
    Colors.purpleAccent, // Si
  ];

  // REMOVIDO: Melodia Padrão (Agora começa vazia)
  List<SongEvent> currentMelody = [];

  String currentSongTitle = "Nenhuma música carregada";

  double hitLineY = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (isPlaying) {
        _gameLoop(elapsed);
      }
    });
    _preloadAudio();
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
        // Carrega automaticamente a música salva
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

      setState(() {
        currentMelody = jsonList.map((e) => SongEvent.fromJson(e)).toList();
        currentSongTitle = file.uri.pathSegments.last.replaceAll('.json', '');
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Melodia carregada!')));
      }
    } catch (e) {
      debugPrint("Erro ao ler: $e");
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
      timeSinceLastNote = 0.0;

      lastTapTime = null;
      if (recording) {
        recordedMelody.clear();
      }

      isPlaying = true;
      lanePressed = List.filled(7, false);
    });
    _ticker.start();
  }

  void _stopGame() {
    _ticker.stop();
    bool wasRecording = isRecording;

    setState(() {
      isPlaying = false;
      isRecording = false;
      lanePressed = List.filled(7, false);
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

  void _gameLoop(Duration elapsed) {
    setState(() {
      if (isRecording) {
        return;
      }

      double dt = 0.016;
      timeSinceLastNote += dt;

      if (noteIndex < currentMelody.length) {
        // CORREÇÃO: O delay deve ser o da nota atual que queremos spawnar
        // O SongEvent.delay representa "quanto tempo esperar após o evento anterior"
        double waitTime = currentMelody[noteIndex].delay;

        // Removemos o multiplicador 0.8 para a reprodução ser fiel à gravação
        if (timeSinceLastNote >= waitTime) {
          int lane = currentMelody[noteIndex].lane;
          notes.add(Note(
            lane: lane,
            y: -50,
            color: laneColors[lane],
          ));
          noteIndex++;
          timeSinceLastNote = 0.0;
        }
      } else if (notes.isEmpty) {
        _stopGame();
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
    // 1. Se estiver gravando: Toca sempre
    if (isRecording) {
      _playNoteAndAnimate(laneIndex);

      DateTime now = DateTime.now();
      double delay = 0.0;

      if (lastTapTime != null) {
        delay = now.difference(lastTapTime!).inMilliseconds / 1000.0;
      }

      // Delay inicial para a primeira nota
      if (recordedMelody.isEmpty) delay = 1.0;

      recordedMelody.add(SongEvent(laneIndex, delay));
      lastTapTime = now;
      return;
    }

    if (!isPlaying) return;
    if (isDemoMode) return;

    // REMOVIDO: O som tocava imediatamente aqui.
    // Agora só toca se acertar uma nota no bloco abaixo.
    // _playNoteAndAnimate(laneIndex);

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

      // ADICIONADO: Toca som e anima APENAS se acertar
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
                laneCount: 7,
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
                              : (isDemoMode ? 'DEMO MODE' : 'PONTOS'),
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
                  children: List.generate(7, (index) {
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
    double btnWidth = (screenWidth / 7) - 4;
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
