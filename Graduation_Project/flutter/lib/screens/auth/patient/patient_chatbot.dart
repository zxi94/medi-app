import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/chat_service.dart';
import '../../../services/xray_service.dart';

class PatientChatbotScreen extends StatefulWidget {
  const PatientChatbotScreen({super.key});

  @override
  State<PatientChatbotScreen> createState() => _PatientChatbotScreenState();
}

class _PatientChatbotScreenState extends State<PatientChatbotScreen> {
  final _scrollCtrl = ScrollController();
  final _messageCtrl = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isTyping = false;
  String? _selectedFinding;
  final List<String> _possibleFindings = ["General Health"];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatestFindings());
  }

  Future<void> _loadLatestFindings() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final stats = await XrayService().fetchMyStats(token);
      final latest = stats['latestXray'];
      if (latest != null && latest is Map<String, dynamic>) {
        final xray = XrayRecord.fromJson(latest);
        final label = xray.diagnosisLabel;
        if (label != 'Pending Analysis' && label != 'Analyzed') {
          final findings = label
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (findings.isNotEmpty) {
            if (mounted) {
              setState(() {
                _possibleFindings.clear();
                _possibleFindings.addAll(findings);
                _selectedFinding = findings.first;
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  final List<Map<String, dynamic>> _messages = [
    {
      'text':
          "Hello John! 👋 I'm your friendly AI health assistant. I'm here to help you understand your health reports, explain medical terms in simple language, and answer your health questions. How can I help you today?",
      'isUser': false,
      'time': '02:55 PM',
    },
  ];

  List<String> _getQuickQuestions(AppLocalizations loc) {
    if (loc.language == 'Arabic') {
      return [
        'ماذا تعني عتامة الرئة؟',
        'ما مدى خطورة حالتي؟',
        'ماذا يمكنني أن أفعل للتعافي؟',
        'متى يجب علي مراجعة الطبيب؟',
      ];
    }
    return [
      'What does lung opacity mean?',
      'How serious is my condition?',
      'What can I do to recover?',
      'When should I see a doctor?',
    ];
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = preset ?? _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true, 'time': _timeNow()});
      _isTyping = true;
      _messageCtrl.clear();
    });
    _scrollToBottom();

    String finding = _selectedFinding ?? 'General Health';

    try {
      final loc = AppLocalizations.of(context)!;
      final langCode = loc.language == 'Arabic' ? 'ar' : 'en';

      final response = await _chatService.askAi(
        token: token,
        question: text,
        finding: finding,
        language: langCode,
      );

      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': response,
          'isUser': false,
          'time': _timeNow(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'text':
              "Sorry, I couldn't connect to the AI service. Please try again.",
          'isUser': false,
          'time': _timeNow(),
        });
      });
    }
    _scrollToBottom();
  }

  String _timeNow() {
    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
            ? 12
            : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final quickQuestions = _getQuickQuestions(loc);

    if (_messages.length == 1 && _messages.first['isUser'] == false) {
      _messages.first['text'] = loc.language == 'Arabic'
          ? "مرحباً! 👋 أنا المساعد الصحي الذكي. أنا هنا لمساعدتك في فهم تقاريرك الصحية، وشرح المصطلحات الطبية، والإجابة على أسئلتك. كيف يمكنني مساعدتك اليوم؟"
          : "Hello! 👋 I'm your friendly AI health assistant. I'm here to help you understand your health reports, explain medical terms, and answer your health questions. How can I help you today?";
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: const SessionAppTopBar(),
      body: Column(
        children: [
          Container(
            color: isDark ? AppTheme.darkCardBg : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.aiHealthAssistant,
                    style: GoogleFonts.dmSans(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                Text(loc.askAboutHealth,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Chat area
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBg : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.favorite_outline,
                                    size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.aiHealthAssistant,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  Text(loc.askAboutHealth,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textSecondary)),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: AppTheme.success,
                                      shape: BoxShape.circle)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _messages.length) {
                              return const _TypingBubble();
                            }
                            final m = _messages[i];
                            return ChatBubble(
                                message: m['text'],
                                isUser: m['isUser'],
                                time: m['time']);
                          },
                        ),
                        const Divider(height: 1),
                        // Dropdown for finding
                        Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, top: 12),
                            child: Row(children: [
                              Text('Discussing:',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                    value: _possibleFindings
                                            .contains(_selectedFinding)
                                        ? _selectedFinding
                                        : (_possibleFindings.isNotEmpty
                                            ? _possibleFindings.first
                                            : null),
                                    isExpanded: true,
                                    isDense: true,
                                    underline: const SizedBox(),
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600),
                                    icon: const Icon(Icons.arrow_drop_down,
                                        color: AppTheme.primary, size: 16),
                                    items: _possibleFindings
                                        .map((f) => DropdownMenuItem(
                                            value: f, child: Text(f)))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null)
                                        setState(() => _selectedFinding = val);
                                    }),
                              ),
                            ])),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageCtrl,
                                  style: GoogleFonts.dmSans(fontSize: 14),
                                  onSubmitted: (_) => _sendMessage(),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Ask me anything about your health...',
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(10)),
                                child: IconButton(
                                  // FIX: removed const, isDark is a runtime value
                                  icon: Icon(Icons.send,
                                      color: isDark
                                          ? AppTheme.darkCardBg
                                          : Colors.white,
                                      size: 18),
                                  onPressed: _sendMessage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: loc.quickQuestions,
                    description: loc.quickAnswers,
                    child: Column(
                      children: quickQuestions
                          .map((q) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => _sendMessage(q),
                                    style: OutlinedButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14)),
                                    child: Text(q,
                                        style:
                                            GoogleFonts.dmSans(fontSize: 13)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: loc.healthTips,
                    child: Column(
                      children: [
                        _TipRow(
                            Icons.medication_outlined,
                            loc.language == 'Arabic'
                                ? 'تناول الأدوية كما هو موصوف'
                                : 'Take medications as prescribed'),
                        _TipRow(
                            Icons.bedtime_outlined,
                            loc.language == 'Arabic'
                                ? 'احصل على 7-9 ساعات من النوم'
                                : 'Get 7-9 hours of sleep'),
                        _TipRow(Icons.water_drop_outlined, loc.stayHydrated),
                        _TipRow(
                            Icons.smoke_free_outlined,
                            loc.language == 'Arabic'
                                ? 'تجنب التدخين'
                                : 'Avoid smoking and alcohol'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.dmSans(fontSize: 14)),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.favorite_outline,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(16)
                  .copyWith(bottomLeft: const Radius.circular(4)),
            ),
            // FIX: removed const from Row, isDark is a runtime value
            child: Row(
              children: List.generate(
                  3,
                  (i) => Container(
                        width: 6,
                        height: 6,
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      )),
            ),
          ),
        ],
      ),
    );
  }
}
