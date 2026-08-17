class CallICEServer {
  const CallICEServer({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  Map<String, Object> toWebRTC() {
    final result = <String, Object>{'urls': urls};
    final username = this.username;
    final credential = this.credential;
    if (username != null) result['username'] = username;
    if (credential != null) result['credential'] = credential;
    return result;
  }
}

class CallICEConfiguration {
  const CallICEConfiguration({required this.servers, required this.expiresAt});

  final List<CallICEServer> servers;
  final DateTime expiresAt;
}
