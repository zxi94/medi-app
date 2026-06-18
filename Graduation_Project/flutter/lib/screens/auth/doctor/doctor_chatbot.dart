import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/chat_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/shared_widgets.dart';
import 'package:mediscan_ai/l10n/app_localizations.dart';

class DoctorChatbotScreen extends StatefulWidget {
  const DoctorChatbotScreen({super.key});

  @override
  State<DoctorChatbotScreen> createState() => _DoctorChatbotScreenState();
}

class _DoctorChatbotScreenState extends State<DoctorChatbotScreen> {
  final _scrollCtrl = ScrollController();
  final _messageCtrl = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isTyping = false;
  String _selectedFinding = 'Aortic enlargement';
  final List<String> _possibleFindings = [
    "Aortic enlargement",
    "Cardiomegaly",
    "Consolidation",
    "Lung Opacity",
    "Nodule/Mass",
    "Pleural effusion",
    "Pleural thickening",
    "Pneumothorax",
    "Pulmonary fibrosis"
  ];

  final List<Map<String, dynamic>> _messages = [
    {
      'text':
          "Hello Dr. Anderson! I'm your AI medical assistant. I can help you analyze X-ray results, compare patient scans, suggest treatment protocols, and clarify medical terminology. How can I assist you today?",
      'isUser': false,
      'time': '02:17 PM',
    },
  ];

  List<String> _getQuickQuestions(AppLocalizations loc) {
    if (loc.language == 'Arabic') {
      return [
        'اشرح نتيجة الذكاء الاصطناعي هذه',
        'قارن مع الأشعة السابقة',
        'ما هي خطوات العلاج المقترحة؟',
        'تفسير درجات الثقة',
      ];
    }
    return [
      'Explain this AI result',
      'Compare to previous X-ray',
      'What treatment steps should be considered?',
      'Interpret the confidence scores',
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

    String finding = _selectedFinding;

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
    final h = now.hour > 12 ? now.hour - 12 : now.hour;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final txtSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final quickQuestions = _getQuickQuestions(loc);

    if (_messages.length == 1 && _messages.first['isUser'] == false) {
      _messages.first['text'] = loc.language == 'Arabic'
          ? "مرحباً دكتور! أنا المساعد الطبي الذكي. يمكنني مساعدتك في تحليل نتائج الأشعة، ومقارنة فحوصات المرضى، واقتراح بروتوكولات العلاج، وتوضيح المصطلحات الطبية. كيف يمكنني مساعدتك اليوم؟"
          : "Hello Doctor! I'm your AI medical assistant. I can help you analyze X-ray results, compare patient scans, suggest treatment protocols, and clarify medical terminology. How can I assist you today?";
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const SessionAppTopBar(),
      body: Column(
        children: [
          // Header
          Container(
            color: theme.appBarTheme.backgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.aiMedicalAssistant,
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.headlineSmall?.color,
                    )),
                Text(loc.askAboutXray,
                    style: GoogleFonts.dmSans(fontSize: 13, color: txtSec)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Chat card
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: theme.cardTheme.shape is RoundedRectangleBorder
                          ? Border.fromBorderSide(
                              (theme.cardTheme.shape as RoundedRectangleBorder)
                                  .side)
                          : Border.all(
                              color: isDark
                                  ? AppTheme.darkBorderColor
                                  : AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        // Card header
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
                                child: const Icon(Icons.smart_toy_outlined,
                                    size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.aiMedicalAssistant,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: theme
                                              .textTheme.titleMedium?.color)),
                                  Text(loc.askAboutXray,
                                      style: GoogleFonts.dmSans(
                                          fontSize: 12, color: txtSec)),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Messages
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _messages.length) {
                              return const _TypingIndicator();
                            }
                            final m = _messages[i];
                            return ChatBubble(
                              message: m['text'],
                              isUser: m['isUser'],
                              time: m['time'],
                            );
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
                                      fontSize: 12, color: txtSec)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                    value: _selectedFinding,
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
                        // Input
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
                                        'Ask a question about X-ray analysis...',
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
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white, size: 18),
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
                  // Quick Questions
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
                                          horizontal: 16, vertical: 14),
                                    ),
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
                  // AI Capabilities
                  SectionCard(
                    title: loc.aiCapabilities,
                    child: Column(
                      children: [
                        _CapabilityRow(
                            loc.language == 'Arabic'
                                ? 'شرح نتائج الذكاء الاصطناعي'
                                : 'Explain AI diagnosis results',
                            theme: theme),
                        _CapabilityRow(
                            loc.language == 'Arabic'
                                ? 'مقارنة أشعة المرضى'
                                : 'Compare patient scans',
                            theme: theme),
                        _CapabilityRow(
                            loc.language == 'Arabic'
                                ? 'اقتراح بروتوكولات العلاج'
                                : 'Suggest treatment protocols',
                            theme: theme),
                        _CapabilityRow(
                            loc.language == 'Arabic'
                                ? 'توضيح المصطلحات الطبية'
                                : 'Clarify medical terminology',
                            theme: theme),
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

class _CapabilityRow extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _CapabilityRow(this.text, {required this.theme});

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
          Text(text,
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

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
            child: const Icon(Icons.smart_toy_outlined,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkRowBg : const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(16)
                  .copyWith(bottomLeft: const Radius.circular(4)),
            ),
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
