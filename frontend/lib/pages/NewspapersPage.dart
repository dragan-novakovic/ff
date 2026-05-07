import 'package:ff/blocs/GameAreaBlocs.dart';
import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NewspapersPage extends StatefulWidget {
  final User user;
  const NewspapersPage({super.key, required this.user});

  @override
  State<NewspapersPage> createState() => _NewspapersPageState();
}

class _NewspapersPageState extends State<NewspapersPage> {
  late final NewspapersBloc _newspapersBloc;
  late final LoginBloc _loginBloc;
  final TextEditingController _newspaperNameController =
      TextEditingController();
  final TextEditingController _newspaperDescriptionController =
      TextEditingController();
  final TextEditingController _articleTitleController = TextEditingController();
  final TextEditingController _articleContentController =
      TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newspapersBloc = Provider.of<NewspapersBloc>(context, listen: false);
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    await _newspapersBloc.load(widget.user.uid);
  }

  Future<void> _createNewspaper() async {
    final name = _newspaperNameController.text.trim();
    final description = _newspaperDescriptionController.text.trim();
    if (name.length < 3 || name.length > 80 || description.length > 500) {
      _showMessage('Use a 3-80 character name and 500 character description.');
      return;
    }

    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.createNewspaper(
      playerId: widget.user.uid,
      name: name,
      description: description,
    );
    if (result != null) {
      _newspaperNameController.clear();
      _newspaperDescriptionController.clear();
    }
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<void> _selectNewspaper(Newspaper newspaper) async {
    _commentController.clear();
    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    await _newspapersBloc.loadArticles(
      playerId: widget.user.uid,
      newspaperId: newspaper.newspaperId,
    );
  }

  Future<void> _publishArticle(Newspaper newspaper) async {
    final title = _articleTitleController.text.trim();
    final content = _articleContentController.text.trim();
    if (title.length < 3 || title.length > 140) {
      _showMessage('Article title must be between 3 and 140 characters.');
      return;
    }
    if (content.length < 20 || content.length > 10000) {
      _showMessage('Article content must be between 20 and 10000 characters.');
      return;
    }

    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.publishArticle(
      playerId: widget.user.uid,
      newspaperId: newspaper.newspaperId,
      title: title,
      content: content,
    );
    if (result != null) {
      _articleTitleController.clear();
      _articleContentController.clear();
    }
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<void> _readArticle(NewspaperArticle article) async {
    _commentController.clear();
    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    await _newspapersBloc.readArticle(
      playerId: widget.user.uid,
      articleId: article.articleId,
    );
  }

  Future<void> _commentOnSelectedArticle(NewspaperArticle article) async {
    final content = _commentController.text.trim();
    if (content.isEmpty || content.length > 1000) {
      _showMessage('Comment content must be between 1 and 1000 characters.');
      return;
    }

    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.comment(
      playerId: widget.user.uid,
      articleId: article.articleId,
      content: content,
    );
    if (result != null) {
      _commentController.clear();
    }
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<void> _vote(NewspaperArticle article, int value) async {
    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.vote(
      playerId: widget.user.uid,
      articleId: article.articleId,
      value: value,
    );
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<void> _toggleSubscription(Newspaper newspaper) async {
    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.subscribe(
      playerId: widget.user.uid,
      newspaperId: newspaper.newspaperId,
      subscribe: !newspaper.isSubscribed,
    );
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<void> _reportNewspaper(Newspaper newspaper) async {
    final reason = await _promptReportReason('Report ${newspaper.name}');
    if (reason == null) {
      return;
    }

    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.reportNewspaper(
      playerId: widget.user.uid,
      newspaperId: newspaper.newspaperId,
      reason: reason,
    );
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<void> _reportArticle(NewspaperArticle article) async {
    final reason = await _promptReportReason('Report ${article.title}');
    if (reason == null) {
      return;
    }

    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.reportArticle(
      playerId: widget.user.uid,
      articleId: article.articleId,
      reason: reason,
    );
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<void> _reportComment(
      NewspaperArticle article, NewspaperComment comment) async {
    final reason = await _promptReportReason('Report comment');
    if (reason == null) {
      return;
    }

    _newspapersBloc.setBearerToken(_loginBloc.currentToken);
    final result = await _newspapersBloc.reportArticleComment(
      playerId: widget.user.uid,
      articleId: article.articleId,
      commentId: comment.commentId,
      reason: reason,
    );
    _showMessage(result?.message ?? _newspapersBloc.error);
  }

  Future<String?> _promptReportReason(String title) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain why this content should be reviewed.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Submit report'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) {
      return null;
    }
    if (reason.length < 5 || reason.length > 500) {
      _showMessage('Report reason must be between 5 and 500 characters.');
      return null;
    }
    return reason;
  }

  void _showMessage(String? message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _newspaperNameController.dispose();
    _newspaperDescriptionController.dispose();
    _articleTitleController.dispose();
    _articleContentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media: Newspapers')),
      body: Consumer<NewspapersBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.catalog == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bloc.error != null && bloc.catalog == null) {
            return _ErrorState(message: bloc.error!, onRetry: _load);
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CreateNewspaperCard(
                  nameController: _newspaperNameController,
                  descriptionController: _newspaperDescriptionController,
                  isCreating: bloc.isCreatingNewspaper,
                  onCreate: _createNewspaper,
                ),
                if (bloc.error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading:
                          const Icon(Icons.warning_amber, color: Colors.red),
                      title: Text(bloc.error!),
                    ),
                  ),
                const SizedBox(height: 12),
                _NewspaperListSection(
                  newspapers: bloc.newspapers,
                  selectedNewspaperId: bloc.selectedNewspaperId,
                  subscribingNewspaperIds: bloc.subscribingNewspaperIds,
                  currentPlayerId: widget.user.uid,
                  onSelect: _selectNewspaper,
                  onToggleSubscription: _toggleSubscription,
                  onReport: _reportNewspaper,
                ),
                const SizedBox(height: 12),
                _ArticleSection(
                  newspaper: bloc.selectedNewspaper,
                  articles: bloc.articles,
                  selectedArticle: bloc.selectedArticle,
                  currentPlayerId: widget.user.uid,
                  isLoading: bloc.isLoadingArticles,
                  isPublishing: bloc.isPublishingArticle,
                  isCommenting: bloc.isCommenting,
                  votingArticleIds: bloc.votingArticleIds,
                  titleController: _articleTitleController,
                  contentController: _articleContentController,
                  commentController: _commentController,
                  onPublish: _publishArticle,
                  onRead: _readArticle,
                  onVote: _vote,
                  onComment: _commentOnSelectedArticle,
                  onReportArticle: _reportArticle,
                  onReportComment: _reportComment,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CreateNewspaperCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool isCreating;
  final Future<void> Function() onCreate;

  const _CreateNewspaperCard({
    required this.nameController,
    required this.descriptionController,
    required this.isCreating,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start a newspaper',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Create a persisted publication owned by your player.'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Newspaper name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isCreating ? null : onCreate,
                icon: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business),
                label: const Text('Create newspaper'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewspaperListSection extends StatelessWidget {
  final List<Newspaper> newspapers;
  final String? selectedNewspaperId;
  final Set<String> subscribingNewspaperIds;
  final String currentPlayerId;
  final Future<void> Function(Newspaper newspaper) onSelect;
  final Future<void> Function(Newspaper newspaper) onToggleSubscription;
  final Future<void> Function(Newspaper newspaper) onReport;

  const _NewspaperListSection({
    required this.newspapers,
    required this.selectedNewspaperId,
    required this.subscribingNewspaperIds,
    required this.currentPlayerId,
    required this.onSelect,
    required this.onToggleSubscription,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    if (newspapers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No newspapers yet. Create the first player-run publication.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Newspapers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...newspapers.map((newspaper) {
          final selected = newspaper.newspaperId == selectedNewspaperId;
          final isOwner = _samePlayer(newspaper.ownerPlayerId, currentPlayerId);
          final isSubscribing =
              subscribingNewspaperIds.contains(newspaper.newspaperId);
          return Card(
            color: selected ? Colors.blue.shade50 : null,
            child: ListTile(
              leading: Icon(
                isOwner ? Icons.edit_note : Icons.newspaper,
                color: selected ? Colors.blue : Colors.blueGrey,
              ),
              title: Text(newspaper.name),
              subtitle: Text(
                [
                  newspaper.description.isEmpty
                      ? 'No description'
                      : newspaper.description,
                  '${newspaper.articleCount} articles',
                  '${newspaper.subscriberCount} subscribers',
                ].join(' • '),
              ),
              selected: selected,
              onTap: () => onSelect(newspaper),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: isSubscribing
                        ? null
                        : () => onToggleSubscription(newspaper),
                    icon: isSubscribing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(newspaper.isSubscribed
                            ? Icons.notifications_off
                            : Icons.notifications_active),
                    label: Text(
                        newspaper.isSubscribed ? 'Unsubscribe' : 'Subscribe'),
                  ),
                  IconButton(
                    tooltip: 'Report newspaper',
                    onPressed: () => onReport(newspaper),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ArticleSection extends StatelessWidget {
  final Newspaper? newspaper;
  final List<NewspaperArticle> articles;
  final NewspaperArticle? selectedArticle;
  final String currentPlayerId;
  final bool isLoading;
  final bool isPublishing;
  final bool isCommenting;
  final Set<String> votingArticleIds;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final TextEditingController commentController;
  final Future<void> Function(Newspaper newspaper) onPublish;
  final Future<void> Function(NewspaperArticle article) onRead;
  final Future<void> Function(NewspaperArticle article, int value) onVote;
  final Future<void> Function(NewspaperArticle article) onComment;
  final Future<void> Function(NewspaperArticle article) onReportArticle;
  final Future<void> Function(
      NewspaperArticle article, NewspaperComment comment) onReportComment;

  const _ArticleSection({
    required this.newspaper,
    required this.articles,
    required this.selectedArticle,
    required this.currentPlayerId,
    required this.isLoading,
    required this.isPublishing,
    required this.isCommenting,
    required this.votingArticleIds,
    required this.titleController,
    required this.contentController,
    required this.commentController,
    required this.onPublish,
    required this.onRead,
    required this.onVote,
    required this.onComment,
    required this.onReportArticle,
    required this.onReportComment,
  });

  @override
  Widget build(BuildContext context) {
    final currentNewspaper = newspaper;
    if (currentNewspaper == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Select a newspaper to read and publish articles.'),
        ),
      );
    }

    final isOwner =
        _samePlayer(currentNewspaper.ownerPlayerId, currentPlayerId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.newspaper, color: Colors.blue),
            title: Text(currentNewspaper.name),
            subtitle: Text(
              'Owned by ${currentNewspaper.ownerPlayerId} • updated ${_formatDate(currentNewspaper.updatedAt)}',
            ),
          ),
        ),
        if (isOwner)
          _PublishArticleCard(
            titleController: titleController,
            contentController: contentController,
            isPublishing: isPublishing,
            onPublish: () => onPublish(currentNewspaper),
          )
        else
          Card(
            color: Colors.grey.shade100,
            child: const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Only the owner can publish in this newspaper.'),
            ),
          ),
        const SizedBox(height: 12),
        Text('Articles', style: Theme.of(context).textTheme.titleLarge),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (articles.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No articles published yet.'),
            ),
          )
        else
          ...articles.map(
            (article) => _ArticleCard(
              article: selectedArticle?.articleId == article.articleId
                  ? selectedArticle!
                  : article,
              expanded: selectedArticle?.articleId == article.articleId,
              isVoting: votingArticleIds.contains(article.articleId),
              isCommenting: isCommenting,
              commentController: commentController,
              onRead: () => onRead(article),
              onVote: (value) => onVote(article, value),
              onComment: () => onComment(selectedArticle ?? article),
              onReportArticle: () => onReportArticle(article),
              onReportComment: (comment) =>
                  onReportComment(selectedArticle ?? article, comment),
            ),
          ),
      ],
    );
  }
}

class _PublishArticleCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController contentController;
  final bool isPublishing;
  final Future<void> Function() onPublish;

  const _PublishArticleCard({
    required this.titleController,
    required this.contentController,
    required this.isPublishing,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Publish article',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              maxLength: 10000,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Article body',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isPublishing ? null : onPublish,
                icon: isPublishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish),
                label: const Text('Publish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final NewspaperArticle article;
  final bool expanded;
  final bool isVoting;
  final bool isCommenting;
  final TextEditingController commentController;
  final Future<void> Function() onRead;
  final Future<void> Function(int value) onVote;
  final Future<void> Function() onComment;
  final Future<void> Function() onReportArticle;
  final Future<void> Function(NewspaperComment comment) onReportComment;

  const _ArticleCard({
    required this.article,
    required this.expanded,
    required this.isVoting,
    required this.isCommenting,
    required this.commentController,
    required this.onRead,
    required this.onVote,
    required this.onComment,
    required this.onReportArticle,
    required this.onReportComment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(article.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'By ${article.authorPlayerId} • ${_formatDate(article.publishedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(expanded ? article.content : article.excerpt),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.how_to_vote, size: 18),
                  label: Text('Score ${article.voteScore}'),
                ),
                Chip(
                  avatar: const Icon(Icons.comment, size: 18),
                  label: Text('${article.commentCount} comments'),
                ),
                TextButton.icon(
                  onPressed: expanded ? null : onRead,
                  icon: const Icon(Icons.chrome_reader_mode),
                  label: Text(expanded ? 'Reading' : 'Read'),
                ),
                TextButton.icon(
                  onPressed: isVoting ? null : () => onVote(1),
                  icon: Icon(
                    Icons.thumb_up,
                    color: article.playerVote == 1 ? Colors.green : null,
                  ),
                  label: Text('${article.upvotes}'),
                ),
                TextButton.icon(
                  onPressed: isVoting ? null : () => onVote(-1),
                  icon: Icon(
                    Icons.thumb_down,
                    color: article.playerVote == -1 ? Colors.red : null,
                  ),
                  label: Text('${article.downvotes}'),
                ),
                TextButton.icon(
                  onPressed: onReportArticle,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report'),
                ),
              ],
            ),
            if (expanded) ...[
              const Divider(height: 24),
              Text('Comments', style: Theme.of(context).textTheme.titleSmall),
              if (article.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No comments yet.'),
                )
              else
                ...article.comments.map(
                  (comment) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person),
                    title: Text(comment.content),
                    subtitle: Text(
                      '${comment.authorPlayerId} • ${_formatDate(comment.createdAt)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Report comment',
                      onPressed: () => onReportComment(comment),
                      icon: const Icon(Icons.flag_outlined),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Add comment',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: isCommenting ? null : onComment,
                  icon: isCommenting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.comment),
                  label: const Text('Comment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.newspaper, size: 48, color: Colors.orange),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

bool _samePlayer(String left, String right) =>
    left.toLowerCase() == right.toLowerCase();

String _formatDate(DateTime value) {
  return DateFormat('MMM d, HH:mm').format(value.toLocal());
}
