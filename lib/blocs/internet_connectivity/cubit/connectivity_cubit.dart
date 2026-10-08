import 'dart:async';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
part 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _probeGeneration = 0;

  ConnectivityCubit() : super(ConnectivityState.disconnected) {
    _subscription = Connectivity().onConnectivityChanged.listen(_handleConnectivity);
    _refreshConnectivity();
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> event) async {
    final generation = ++_probeGeneration;

    final hasNetwork = event.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn ||
        result == ConnectivityResult.other);

    if (!hasNetwork) {
      if (!isClosed && generation == _probeGeneration) {
        emit(ConnectivityState.disconnected);
      }
      log('No network transport: $event', name: 'ConnectivityCubit');
      return;
    }

    final online = await _hasInternetAccess();
    if (isClosed || generation != _probeGeneration) return;

    emit(online ? ConnectivityState.connected : ConnectivityState.disconnected);
    log(
      online ? 'Internet available: $event' : 'Network connected but internet unavailable: $event',
      name: 'ConnectivityCubit',
    );
  }

  Future<void> _refreshConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      await _handleConnectivity(result);
    } catch (e) {
      if (!isClosed) emit(ConnectivityState.disconnected);
      log('Connectivity check failed: $e', name: 'ConnectivityCubit');
    }
  }

  Future<bool> _hasInternetAccess() async {
    const endpoints = <String>[
      'https://www.google.com/generate_204',
      'https://connectivitycheck.gstatic.com/generate_204',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(Uri.parse(endpoint))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<void> close() async {
    ++_probeGeneration;
    await _subscription?.cancel();
    return super.close();
  }
}
