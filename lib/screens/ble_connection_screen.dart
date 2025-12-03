import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/ble_repository.dart';
import '../blocs/ble_connection/ble_connection_cubit.dart';

class BleConnectionScreen extends StatefulWidget {
  const BleConnectionScreen({super.key});

  @override
  State<BleConnectionScreen> createState() => _BleConnectionScreenState();
}

class _BleConnectionScreenState extends State<BleConnectionScreen> {
  final BleRepository _bleRepo = BleRepository();
  List<BleDevice> _devices = [];
  bool _simMode = false; // Default to real BLE
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BleConnectionCubit(connectStream: _bleRepo.connectToDevice),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BLE Devices'),
        ),
        body: Column(
          children: [
            // Mode toggle
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BLE Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isScanning
                                ? null
                                : () {
                                    setState(() => _simMode = false);
                                    _bleRepo.setSimulationMode(false);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !_simMode ? Colors.blue : Colors.grey,
                            ),
                            child: const Text('Real BLE'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isScanning
                                ? null
                                : () {
                                    setState(() => _simMode = true);
                                    _bleRepo.setSimulationMode(true);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _simMode ? Colors.amber : Colors.grey,
                            ),
                            child: const Text('Simulation'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Scan button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () async {
                          setState(() => _isScanning = true);
                          List<BleDevice> devices = [];
                          Object? scanError;
                          try {
                            devices = await _bleRepo.scan(forceSimulation: _simMode);
                          } catch (e) {
                            scanError = e;
                          }

                          if (!mounted) return;

                          if (scanError != null) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Błąd skanowania: $scanError')),
                            );
                          } else {
                            setState(() => _devices = devices);
                          }

                          setState(() => _isScanning = false);
                        },
                  icon: _isScanning ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                ),
              ),
            ),
            // Devices list
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Text(_isScanning ? 'Scanning...' : 'No devices found. Tap "Scan Devices" to start.'),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final d = _devices[index];
                        final isSimulated = d.id.startsWith('sim-');
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              isSimulated ? Icons.phonelink_lock : Icons.watch,
                              color: isSimulated ? Colors.amber : Colors.blue,
                            ),
                            title: Text(d.name),
                            subtitle: Text(d.id, style: const TextStyle(fontSize: 12)),
                            trailing: BlocBuilder<BleConnectionCubit, BleConnectionState>(
                              builder: (context, state) {
                                final connected = state.status == BleStatus.connected && state.deviceId == d.id;
                                return ElevatedButton(
                                  onPressed: () {
                                    final cubit = context.read<BleConnectionCubit>();
                                    if (connected) {
                                      cubit.disconnect();
                                    } else {
                                      cubit.connect(d.id, d.name);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: connected ? Colors.red : Colors.green,
                                  ),
                                  child: Text(connected ? 'Disconnect' : 'Connect'),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Status bar
            BlocBuilder<BleConnectionCubit, BleConnectionState>(
              builder: (context, state) {
                return Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(12.0),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${state.status.toString().split('.').last}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (state.deviceName != null) Text('Device: ${state.deviceName}'),
                      Text('Mode: ${_simMode ? 'Simulation' : 'Real BLE'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bleRepo.dispose();
    super.dispose();
  }
}
