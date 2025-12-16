import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/providers/providers.dart';
import 'package:provider/provider.dart';

class WatchPartyRoomDialog extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final Duration? currentPosition;
  final bool isPlaying;

  const WatchPartyRoomDialog({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
    this.currentPosition,
    this.isPlaying = false,
  });

  @override
  State<WatchPartyRoomDialog> createState() => _WatchPartyRoomDialogState();
}

enum WatchPartyMode { localNetwork, online }

class _WatchPartyRoomDialogState extends State<WatchPartyRoomDialog> {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  
  bool _isCreating = false;
  bool _isJoining = false;
  WatchPartyRoom? _createdRoom;
  String? _localIp;
  int? _serverPort;
  WatchPartyMode _mode = WatchPartyMode.localNetwork;

  @override
  void initState() {
    super.initState();
    _loadLocalIp();
    _nameController.text = 'User ${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  Future<void> _loadLocalIp() async {
    final watchPartyProvider = Provider.of<WatchPartyProvider>(context, listen: false);
    final ip = await watchPartyProvider.watchPartyService.getLocalIp();
    setState(() {
      _localIp = ip;
    });
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final watchPartyProvider = Provider.of<WatchPartyProvider>(context, listen: false);
      final room = await watchPartyProvider.createRoom(
        _nameController.text.trim(),
        useOnline: _mode == WatchPartyMode.online,
      );

      if (_mode == WatchPartyMode.localNetwork) {
        final port = watchPartyProvider.watchPartyService.getServerPort();
        setState(() {
          _serverPort = port;
        });
      }
      
      setState(() {
        _createdRoom = room;
        _isCreating = false;
      });
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating room: $e')),
        );
      }
    }
  }

  Future<void> _joinRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_mode == WatchPartyMode.online) {
      // Online mode: Only need room code
      if (_roomCodeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter room code')),
        );
        return;
      }
    } else {
      // Local network mode: Need IP and Port
      if (_ipController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter host IP address')),
        );
        return;
      }

      if (_portController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter host port')),
        );
        return;
      }
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final watchPartyProvider = Provider.of<WatchPartyProvider>(context, listen: false);
      final roomCode = _roomCodeController.text.trim();
      
      WatchPartyRoom? room;
      
      if (_mode == WatchPartyMode.online) {
        // Online mode: Join using only room code
        room = await watchPartyProvider.joinRoomOnline(
          _nameController.text.trim(),
          roomCode,
        );
      } else {
        // Local network mode: Join using IP, Port, and optional room code
        final hostIp = _ipController.text.trim();
        final hostPort = int.parse(_portController.text.trim());
        room = await watchPartyProvider.joinRoom(
          _nameController.text.trim(),
          hostIp,
          hostPort,
          roomCode.isEmpty ? '' : roomCode,
        );
      }

      if (room == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _mode == WatchPartyMode.online
                    ? 'Failed to join room. Check room code.'
                    : 'Failed to join room. Check IP, port, and room code.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(room);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining room: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_createdRoom != null) {
      return _buildRoomCreatedView();
    }

    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'Watch Party',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Watch videos together with friends',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            // Mode selector
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mode = WatchPartyMode.localNetwork;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _mode == WatchPartyMode.localNetwork
                                  ? Colors.amber.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _mode == WatchPartyMode.localNetwork
                                    ? Colors.amber
                                    : Colors.grey[700]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.wifi,
                                  color: _mode == WatchPartyMode.localNetwork
                                      ? Colors.amber
                                      : Colors.grey[400],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Local Network',
                                  style: TextStyle(
                                    color: _mode == WatchPartyMode.localNetwork
                                        ? Colors.amber
                                        : Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Same WiFi',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mode = WatchPartyMode.online;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _mode == WatchPartyMode.online
                                  ? Colors.amber.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _mode == WatchPartyMode.online
                                    ? Colors.amber
                                    : Colors.grey[700]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud,
                                  color: _mode == WatchPartyMode.online
                                      ? Colors.amber
                                      : Colors.grey[400],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Online',
                                  style: TextStyle(
                                    color: _mode == WatchPartyMode.online
                                        ? Colors.amber
                                        : Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Any Network',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.amber),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            
            // Create Room button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text(
                        'Create Room',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[700])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 16),
            
            // Join Room section
            if (_mode == WatchPartyMode.online)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Get room code from the host',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The host will see a 6-digit room code after creating a room. Ask them to share it with you.',
                      style: TextStyle(
                        color: Colors.amber[200],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Get connection info from the host',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The host will see their IP address and Port number after creating a room. Ask them to share both values with you.',
                      style: TextStyle(
                        color: Colors.amber[200],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            
            // Room Code (always shown, required for online)
            TextField(
              controller: _roomCodeController,
              decoration: InputDecoration(
                labelText: _mode == WatchPartyMode.online
                    ? 'Room Code *'
                    : 'Room Code (Optional)',
                hintText: '123456',
                helperText: _mode == WatchPartyMode.online
                    ? 'Required for online rooms'
                    : 'Optional for local network rooms',
                labelStyle: const TextStyle(color: Colors.grey),
                hintStyle: TextStyle(color: Colors.grey[600]),
                helperStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.amber),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            
            // IP and Port (only for local network)
            if (_mode == WatchPartyMode.localNetwork) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'Host IP Address *',
                  hintText: '192.168.1.100',
                  helperText: 'Get this from the host (shown in their "Connection Info")',
                  helperMaxLines: 2,
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  helperStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portController,
                decoration: InputDecoration(
                  labelText: 'Port Number *',
                  hintText: '8080',
                  helperText: 'Port is a number (like 8080, 54321, etc.). Get this from the host.',
                  helperMaxLines: 2,
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  helperStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _joinRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
                child: _isJoining
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Join Room',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCreatedView() {
    final isOnline = _mode == WatchPartyMode.online;
    final connectionInfo = isOnline 
        ? _createdRoom!.roomCode ?? 'N/A'
        : '$_localIp:$_serverPort';
    final qrData = isOnline
        ? _createdRoom!.roomCode ?? ''
        : '$_localIp:$_serverPort:${_createdRoom!.roomCode}';
    
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'Room Created!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this with your friends',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 24),
            
            // Room Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Room Code',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _createdRoom!.roomCode ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Connection Info - Show different info based on mode
            if (_mode == WatchPartyMode.online)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share with guests',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Guests only need the room code to join from anywhere!',
                              style: TextStyle(
                                color: Colors.amber[200],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Info (Share with guests)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'IP Address',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _localIp ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Port',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _serverPort?.toString() ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.amber),
                          onPressed: () => _copyToClipboard(connectionInfo),
                          tooltip: 'Copy connection info',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Guests need both IP and Port to join',
                              style: TextStyle(
                                color: Colors.amber[200],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_createdRoom),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Start Watching',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

