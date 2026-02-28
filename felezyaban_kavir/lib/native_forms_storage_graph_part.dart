part of 'main.dart';

class _NativeAttachmentFile {
  const _NativeAttachmentFile({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}

Future<_NativeAttachmentFile?> _pickNativeAttachmentFile() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: false,
    type: FileType.any,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final selected = result.files.first;
  final filePath = selected.path;
  if (filePath == null || filePath.trim().isEmpty) {
    throw StateError('Selected file path is unavailable.');
  }
  return _NativeAttachmentFile(
    path: filePath,
    name: selected.name,
    size: selected.size,
  );
}

String _formatAttachmentSizeFa(int bytes) {
  final safeBytes = bytes < 0 ? 0 : bytes;
  if (safeBytes < 1024) {
    return '${_toPersianDigits(safeBytes.toString())} بایت';
  }
  final kb = safeBytes / 1024;
  if (kb < 1024) {
    return '${_formatFaNumber(kb, maxFraction: 1)} کیلوبایت';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${_formatFaNumber(mb, maxFraction: 1)} مگابایت';
  }
  final gb = mb / 1024;
  return '${_formatFaNumber(gb, maxFraction: 2)} گیگابایت';
}

class _AttachmentPickerCard extends StatelessWidget {
  const _AttachmentPickerCard({
    required this.file,
    required this.onPick,
    required this.enabled,
    this.onClear,
  });

  final _NativeAttachmentFile? file;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedFile = file;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'پیوست (اختیاری)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: enabled ? onPick : null,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(selectedFile == null ? 'انتخاب فایل' : 'تغییر'),
                ),
                if (selectedFile != null)
                  IconButton(
                    onPressed: enabled ? onClear : null,
                    tooltip: 'حذف پیوست',
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (selectedFile == null)
              Text(
                'فایلی انتخاب نشده است.',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFile.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatAttachmentSizeFa(selectedFile.size),
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _WarehouseGraphNodeTone { central, project, hot, consumed, buy }

enum _WarehouseGraphEdgeTone { purchase, transfer, consumption }

class _WarehouseGraphNode {
  const _WarehouseGraphNode({
    required this.id,
    required this.label,
    required this.caption,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.tone,
  });

  final String id;
  final String label;
  final String caption;
  final double x;
  final double y;
  final double width;
  final double height;
  final _WarehouseGraphNodeTone tone;

  bool get isCompact =>
      tone == _WarehouseGraphNodeTone.buy ||
      tone == _WarehouseGraphNodeTone.hot ||
      tone == _WarehouseGraphNodeTone.consumed;

  bool get isStorageNode =>
      tone == _WarehouseGraphNodeTone.project ||
      tone == _WarehouseGraphNodeTone.central;
}

class _WarehouseGraphEdge {
  const _WarehouseGraphEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.quantity,
    required this.label,
    required this.tone,
  });

  final String id;
  final String from;
  final String to;
  final double quantity;
  final String label;
  final _WarehouseGraphEdgeTone tone;

  _WarehouseGraphEdge copyWith({double? quantity, String? label}) {
    return _WarehouseGraphEdge(
      id: id,
      from: from,
      to: to,
      quantity: quantity ?? this.quantity,
      label: label ?? this.label,
      tone: tone,
    );
  }
}

class _WarehouseGraphModel {
  const _WarehouseGraphModel({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.nodes,
    required this.edges,
    required this.emptyStateMessage,
  });

  final double canvasWidth;
  final double canvasHeight;
  final List<_WarehouseGraphNode> nodes;
  final List<_WarehouseGraphEdge> edges;
  final String emptyStateMessage;
}

class _WarehouseGraphPoint {
  const _WarehouseGraphPoint(this.x, this.y);

  final double x;
  final double y;
}

class _WarehouseGraphEdgeStyle {
  const _WarehouseGraphEdgeStyle({required this.color, this.dashed = false});

  final Color color;
  final bool dashed;
}

class _WarehouseGraphCard extends StatelessWidget {
  const _WarehouseGraphCard({
    required this.graph,
    required this.rows,
    required this.hasSelectedMaterial,
    required this.hasDateFilter,
  });

  final Map<String, dynamic> graph;
  final List<Map<String, dynamic>> rows;
  final bool hasSelectedMaterial;
  final bool hasDateFilter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth =
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final model = _buildWarehouseGraphModel(
              graph: graph,
              rows: rows,
              viewportWidth: viewportWidth,
              hasSelectedMaterial: hasSelectedMaterial,
              hasDateFilter: hasDateFilter,
            );
            final buy = _asMap(graph['buy']);
            final central = _asMap(graph['central']);
            final hot = _asMap(graph['hot']);
            final consumed = _asMap(graph['consumed']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'گراف ارتباط انبارها',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  hasSelectedMaterial
                      ? 'نمایش بر اساس کالای انتخاب‌شده'
                      : 'برای نمایش گراف ابتدا کالا را انتخاب کنید.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryMetricChip(
                      label: 'خرید',
                      value: _formatFaNumber(_dynamicDouble(buy['count'])),
                    ),
                    _SummaryMetricChip(
                      label: 'انبار اصلی',
                      value: _formatFaNumber(_dynamicDouble(central['count'])),
                    ),
                    _SummaryMetricChip(
                      label: 'انبار داغی',
                      value: _formatFaNumber(_dynamicDouble(hot['count'])),
                    ),
                    _SummaryMetricChip(
                      label: 'مصرف شده',
                      value: _formatFaNumber(_dynamicDouble(consumed['count'])),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withAlpha(120),
                    ),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLowest.withAlpha(120),
                  ),
                  child: ClipRect(
                    child: InteractiveViewer(
                      constrained: false,
                      minScale: 0.5,
                      maxScale: 3.0,
                      scaleEnabled: true,
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(120),
                      child: SizedBox(
                        width: model.canvasWidth,
                        height: model.canvasHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _WarehouseGraphPainter(
                                  model: model,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                ),
                              ),
                            ),
                            for (final node in model.nodes)
                              Positioned(
                                left: node.x,
                                top: node.y,
                                width: node.width,
                                height: node.height,
                                child: _WarehouseGraphNodeCard(node: node),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (model.edges.isEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withAlpha(120),
                      ),
                    ),
                    child: Text(
                      model.emptyStateMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _WarehouseGraphLegendChip(
                      label: 'خرید',
                      color: Color(0xFF8B5CF6),
                    ),
                    _WarehouseGraphLegendChip(
                      label: 'انتقال',
                      color: Color(0xFF10B981),
                    ),
                    _WarehouseGraphLegendChip(
                      label: 'مصرف',
                      color: Color(0xFFF97316),
                      dashed: true,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WarehouseGraphLegendChip extends StatelessWidget {
  const _WarehouseGraphLegendChip({
    required this.label,
    required this.color,
    this.dashed = false,
  });

  final String label;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(120),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            child: dashed
                ? CustomPaint(
                    size: const Size(20, 8),
                    painter: _LegendDashPainter(color),
                  )
                : Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _LegendDashPainter extends CustomPainter {
  const _LegendDashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(
      canvas,
      const Offset(0, 4),
      Offset(size.width, 4),
      paint,
      dashLength: 5,
      gapLength: 3,
    );
  }

  @override
  bool shouldRepaint(covariant _LegendDashPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _WarehouseGraphNodeCard extends StatelessWidget {
  const _WarehouseGraphNodeCard({required this.node});

  final _WarehouseGraphNode node;

  @override
  Widget build(BuildContext context) {
    final borderColor = _warehouseGraphNodeBorderColor(node.tone);
    final iconColor = _warehouseGraphNodeIconColor(node.tone);
    final titleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, height: 1.25);
    final captionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).hintColor,
      height: 1.2,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.8),
        color: Theme.of(context).colorScheme.surface.withAlpha(246),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: node.isCompact ? 10 : 12,
          vertical: node.isCompact ? 8 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: node.isCompact
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: node.isStorageNode
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Icon(
                  _warehouseGraphNodeIcon(node.tone),
                  size: node.isCompact ? 16 : 18,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.label,
                    maxLines: node.isStorageNode ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              node.caption,
              maxLines: node.isCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: captionStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseGraphPainter extends CustomPainter {
  const _WarehouseGraphPainter({
    required this.model,
    required this.backgroundColor,
  });

  final _WarehouseGraphModel model;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeById = <String, _WarehouseGraphNode>{
      for (final node in model.nodes) node.id: node,
    };
    final edgeOffsets = _buildGraphEdgeOffsets(model.edges);

    for (final edge in model.edges) {
      final sourceNode = nodeById[edge.from];
      final targetNode = nodeById[edge.to];
      if (sourceNode == null || targetNode == null) {
        continue;
      }

      final sourceCenter = _nodeCenter(sourceNode);
      final targetCenter = _nodeCenter(targetNode);
      final baseStart = _projectPointOnNodeBoundary(sourceNode, targetCenter);
      final baseEnd = _projectPointOnNodeBoundary(targetNode, sourceCenter);

      final dx = baseEnd.x - baseStart.x;
      final dy = baseEnd.y - baseStart.y;
      final length = _hypot(dx, dy);
      final safeLength = length == 0 ? 1.0 : length;
      final normalX = -dy / safeLength;
      final normalY = dx / safeLength;
      final offset = edgeOffsets[edge.id] ?? 0;

      final start = Offset(
        baseStart.x + normalX * offset,
        baseStart.y + normalY * offset,
      );
      final end = Offset(
        baseEnd.x + normalX * offset,
        baseEnd.y + normalY * offset,
      );
      final style = _warehouseGraphEdgeStyle(edge.tone);
      final linePaint = Paint()
        ..color = style.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (style.dashed) {
        _drawDashedLine(canvas, start, end, linePaint);
      } else {
        canvas.drawLine(start, end, linePaint);
      }
      _drawArrowHead(canvas, start: start, end: end, color: style.color);

      final labelCenter = Offset(
        (start.dx + end.dx) / 2 + normalX * 10,
        (start.dy + end.dy) / 2 + normalY * 10,
      );
      _drawEdgeLabel(
        canvas,
        center: labelCenter,
        text: edge.label,
        color: style.color,
      );
    }
  }

  void _drawEdgeLabel(
    Canvas canvas, {
    required Offset center,
    required String text,
    required Color color,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final rect = Rect.fromCenter(
      center: center,
      width: textPainter.width + 14,
      height: textPainter.height + 8,
    );
    final bubble = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(bubble, Paint()..color = backgroundColor.withAlpha(245));
    canvas.drawRRect(
      bubble,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WarehouseGraphPainter oldDelegate) {
    return oldDelegate.model != model ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

_WarehouseGraphModel _buildWarehouseGraphModel({
  required Map<String, dynamic> graph,
  required List<Map<String, dynamic>> rows,
  required double viewportWidth,
  required bool hasSelectedMaterial,
  required bool hasDateFilter,
}) {
  final buyAmount = _dynamicDouble(_asMap(graph['buy'])['count']) ?? 0;
  final centralAmount = _dynamicDouble(_asMap(graph['central'])['count']) ?? 0;
  final hotAmount = _dynamicDouble(_asMap(graph['hot'])['count']) ?? 0;
  final consumedAmount =
      _dynamicDouble(_asMap(graph['consumed'])['count']) ?? 0;
  final projectStorages = _asMapList(graph['project_storages']).toList()
    ..sort(
      (a, b) =>
          _dynamicString(a['title']).compareTo(_dynamicString(b['title'])),
    );
  final graphEdges = _asMap(graph['edges']);

  final outerBaseNodes = <Map<String, dynamic>>[
    for (final storage in projectStorages)
      {
        'id': 'storage-${_dynamicInt(storage['storage_id']) ?? 0}',
        'label': _dynamicString(storage['title'], '-'),
        'caption': _toCountUnit(_dynamicDouble(storage['count']) ?? 0),
        'tone': _WarehouseGraphNodeTone.project,
      },
  ];

  const outerNodeWidth = 190.0;
  const outerNodeHeight = 88.0;
  const middleNodeWidth = 168.0;
  const middleNodeHeight = 64.0;
  const paddingX = 44.0;
  const paddingY = 36.0;
  const middlePairGap = 30.0;
  const buyToCentralGap = 30.0;
  const centralToRingGap = 24.0;

  final ringNodeCount = outerBaseNodes.length + 1;
  final projectNodeDiagonal = _hypot(outerNodeWidth, outerNodeHeight);
  final coreNodeDiagonal = _hypot(middleNodeWidth, middleNodeHeight);
  final requiredProjectCenterDistance = projectNodeDiagonal + 20;
  final radiusByAdjacency = ringNodeCount > 1
      ? requiredProjectCenterDistance /
            (2 * math.sin(math.pi / ringNodeCount.toDouble()))
      : 0.0;
  final coreOffsetFromCenter = middleNodeWidth / 2 + middlePairGap / 2;
  final requiredProjectToCoreCenterDistance =
      projectNodeDiagonal / 2 + coreNodeDiagonal / 2 + 20;
  final radiusByCoreClearance =
      coreOffsetFromCenter + requiredProjectToCoreCenterDistance;
  final ringRadius = math.max(
    420.0,
    math.max(radiusByAdjacency + 36, radiusByCoreClearance + 36),
  );

  final widthRequired = 2 * (ringRadius + outerNodeWidth / 2 + paddingX);
  final viewportCanvasWidth = math.max(980.0, viewportWidth - 24);
  final canvasWidth = math.max(widthRequired, viewportCanvasWidth);
  final centerX = canvasWidth / 2;
  final centerColumnX = (centerX - middleNodeWidth / 2).roundToDouble();

  final buyY = paddingY + 6;
  final centralY = buyY + middleNodeHeight + buyToCentralGap;
  final centralBottom = centralY + middleNodeHeight;
  final ringCenterY =
      (centralBottom + centralToRingGap + outerNodeHeight / 2 + ringRadius)
          .roundToDouble();
  final middlePairY = (ringCenterY - middleNodeHeight / 2).roundToDouble();

  final consumedX = (centerX - middleNodeWidth - middlePairGap / 2)
      .roundToDouble();
  final hotX = (centerX + middlePairGap / 2).roundToDouble();
  final canvasHeight = math.max(
    940.0,
    ringCenterY + ringRadius + outerNodeHeight / 2 + paddingY,
  );

  final ringSeedNodes = <Map<String, dynamic>>[
    {
      'id': 'central',
      'label': 'انبار اصلی',
      'caption': _toCountUnit(centralAmount),
      'tone': _WarehouseGraphNodeTone.central,
    },
    ...outerBaseNodes,
  ];

  final ringNodes = <_WarehouseGraphNode>[];
  const startAngle = -math.pi / 2;
  for (var index = 0; index < ringSeedNodes.length; index++) {
    final node = ringSeedNodes[index];
    final angle = startAngle + (index * math.pi * 2) / ringNodeCount.toDouble();
    final x = (centerX + ringRadius * math.cos(angle) - outerNodeWidth / 2)
        .roundToDouble();
    final y = (ringCenterY + ringRadius * math.sin(angle) - outerNodeHeight / 2)
        .roundToDouble();
    ringNodes.add(
      _WarehouseGraphNode(
        id: _dynamicString(node['id']),
        label: _dynamicString(node['label'], '-'),
        caption: _dynamicString(node['caption']),
        x: x,
        y: y,
        width: outerNodeWidth,
        height: outerNodeHeight,
        tone: node['tone'] as _WarehouseGraphNodeTone,
      ),
    );
  }

  final middleNodes = <_WarehouseGraphNode>[
    _WarehouseGraphNode(
      id: 'buy',
      label: 'خرید',
      caption: _toCountUnit(buyAmount),
      x: centerColumnX,
      y: buyY,
      width: middleNodeWidth,
      height: middleNodeHeight,
      tone: _WarehouseGraphNodeTone.buy,
    ),
    _WarehouseGraphNode(
      id: 'hot',
      label: 'انبار داغی',
      caption: _toCountUnit(hotAmount),
      x: hotX,
      y: middlePairY,
      width: middleNodeWidth,
      height: middleNodeHeight,
      tone: _WarehouseGraphNodeTone.hot,
    ),
    _WarehouseGraphNode(
      id: 'consumed',
      label: 'مصرف شده',
      caption: _toCountUnit(consumedAmount),
      x: consumedX,
      y: middlePairY,
      width: middleNodeWidth,
      height: middleNodeHeight,
      tone: _WarehouseGraphNodeTone.consumed,
    ),
  ];

  final nodes = [...ringNodes, ...middleNodes];
  final nodeIdSet = nodes.map((node) => node.id).toSet();

  final storageIdToNodeId = <int, String>{};
  for (final row in rows) {
    final storageId = _dynamicInt(row['storage_id']);
    if (storageId == null || storageId <= 0) {
      continue;
    }
    final role = _dynamicString(row['role']);
    if (role == 'central') {
      storageIdToNodeId[storageId] = 'central';
    } else if (role == 'hot') {
      storageIdToNodeId[storageId] = 'hot';
    } else {
      storageIdToNodeId[storageId] = 'storage-$storageId';
    }
  }
  for (final storage in projectStorages) {
    final storageId = _dynamicInt(storage['storage_id']);
    if (storageId != null && storageId > 0) {
      storageIdToNodeId[storageId] = 'storage-$storageId';
    }
  }

  final edgeAccumulator = <String, _WarehouseGraphEdge>{};
  void upsertEdge(
    String? from,
    String? to,
    dynamic quantityRaw,
    _WarehouseGraphEdgeTone tone,
  ) {
    if (from == null || to == null || from == to) return;
    if (!nodeIdSet.contains(from) || !nodeIdSet.contains(to)) return;
    final quantity = _dynamicDouble(quantityRaw) ?? 0;
    if (!quantity.isFinite || quantity <= 0) return;
    final key = '${_graphEdgeToneKey(tone)}|$from|$to';
    final existing = edgeAccumulator[key];
    if (existing == null) {
      edgeAccumulator[key] = _WarehouseGraphEdge(
        id: key,
        from: from,
        to: to,
        quantity: quantity,
        label: _formatGraphEdgeQuantity(quantity),
        tone: tone,
      );
      return;
    }
    final nextQuantity = existing.quantity + quantity;
    edgeAccumulator[key] = existing.copyWith(
      quantity: nextQuantity,
      label: _formatGraphEdgeQuantity(nextQuantity),
    );
  }

  for (final edge in _asMapList(graphEdges['purchase'])) {
    final from = _resolveGraphNodeId(
      edge['source'],
      storageIdToNodeId,
      fallback: 'buy',
    );
    final to = _resolveGraphNodeId(
      edge['target_storage_id'],
      storageIdToNodeId,
    );
    upsertEdge(from, to, edge['quantity'], _WarehouseGraphEdgeTone.purchase);
  }
  for (final edge in _asMapList(graphEdges['transfer'])) {
    final from = _resolveGraphNodeId(
      edge['source_storage_id'],
      storageIdToNodeId,
    );
    final to = _resolveGraphNodeId(
      edge['target_storage_id'],
      storageIdToNodeId,
    );
    upsertEdge(from, to, edge['quantity'], _WarehouseGraphEdgeTone.transfer);
  }
  for (final edge in _asMapList(graphEdges['consumption'])) {
    final from = _resolveGraphNodeId(
      edge['source_storage_id'],
      storageIdToNodeId,
    );
    final to = _resolveGraphNodeId(
      edge['target'],
      storageIdToNodeId,
      fallback: 'consumed',
    );
    upsertEdge(from, to, edge['quantity'], _WarehouseGraphEdgeTone.consumption);
  }

  var emptyMessage = _dynamicString(graph['empty_state_message']).trim();
  if (emptyMessage.isEmpty) {
    if (!hasSelectedMaterial) {
      emptyMessage = 'برای نمایش گراف ابتدا کالا را انتخاب کنید.';
    } else if (hasDateFilter) {
      emptyMessage = 'در بازه زمانی انتخاب‌شده داده‌ای برای این کالا یافت نشد.';
    } else {
      emptyMessage = 'برای این کالا گردش تاییدشده‌ای ثبت نشده است.';
    }
  }

  return _WarehouseGraphModel(
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    nodes: nodes,
    edges: edgeAccumulator.values.toList(),
    emptyStateMessage: emptyMessage,
  );
}

String _toCountUnit(num? value) => '${_formatFaNumber(value)} واحد';

String _formatGraphEdgeQuantity(double value) {
  final digits = value == value.roundToDouble() ? 0 : 2;
  return _formatFaNumber(value, maxFraction: digits);
}

String _graphEdgeToneKey(_WarehouseGraphEdgeTone tone) {
  switch (tone) {
    case _WarehouseGraphEdgeTone.purchase:
      return 'purchase';
    case _WarehouseGraphEdgeTone.transfer:
      return 'transfer';
    case _WarehouseGraphEdgeTone.consumption:
      return 'consumption';
  }
}

String? _resolveGraphNodeId(
  dynamic endpoint,
  Map<int, String> storageIdToNodeId, {
  String? fallback,
}) {
  if (endpoint == null) return fallback;

  if (endpoint is num) {
    final id = endpoint.toInt();
    return storageIdToNodeId[id] ?? 'storage-$id';
  }

  final raw = endpoint.toString().trim();
  if (raw.isEmpty) return fallback;
  final normalized = raw.toLowerCase();

  if (normalized == 'buy' || normalized == 'purchase') return 'buy';
  if (normalized == 'central' ||
      normalized == 'main' ||
      normalized == 'main_storage') {
    return 'central';
  }
  if (normalized == 'hot' || normalized == 'hot_storage') return 'hot';
  if (normalized == 'consumed' || normalized == 'consumption') {
    return 'consumed';
  }
  if (RegExp(r'^storage-\d+$').hasMatch(normalized)) {
    return normalized;
  }

  final match = RegExp(r'(\d+)').firstMatch(normalized);
  final id = match == null ? null : int.tryParse(match.group(1)!);
  if (id != null) {
    return storageIdToNodeId[id] ?? 'storage-$id';
  }
  return fallback;
}

Map<String, double> _buildGraphEdgeOffsets(List<_WarehouseGraphEdge> edges) {
  final grouped = <String, List<String>>{};
  for (final edge in edges) {
    final key = '${edge.from}|${edge.to}';
    (grouped[key] ??= <String>[]).add(edge.id);
  }
  final offsets = <String, double>{};
  grouped.forEach((_, ids) {
    final center = (ids.length - 1) / 2;
    for (var index = 0; index < ids.length; index++) {
      offsets[ids[index]] = (index - center) * 14;
    }
  });
  return offsets;
}

_WarehouseGraphPoint _nodeCenter(_WarehouseGraphNode node) {
  return _WarehouseGraphPoint(
    node.x + node.width / 2,
    node.y + node.height / 2,
  );
}

_WarehouseGraphPoint _projectPointOnNodeBoundary(
  _WarehouseGraphNode node,
  _WarehouseGraphPoint towards,
) {
  final center = _nodeCenter(node);
  final halfWidth = node.width / 2;
  final halfHeight = node.height / 2;

  final dx = towards.x - center.x;
  final dy = towards.y - center.y;
  if (dx == 0 && dy == 0) {
    return center;
  }
  final scale =
      1 / math.max(dx.abs() / halfWidth, dy.abs() / halfHeight).toDouble();
  return _WarehouseGraphPoint(center.x + dx * scale, center.y + dy * scale);
}

double _hypot(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

void _drawArrowHead(
  Canvas canvas, {
  required Offset start,
  required Offset end,
  required Color color,
}) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final length = _hypot(dx, dy);
  if (length <= 0.001) return;

  final angle = math.atan2(dy, dx);
  const size = 8.0;
  const spread = math.pi / 6;
  final p1 = end;
  final p2 = Offset(
    end.dx - size * math.cos(angle - spread),
    end.dy - size * math.sin(angle - spread),
  );
  final p3 = Offset(
    end.dx - size * math.cos(angle + spread),
    end.dy - size * math.sin(angle + spread),
  );

  final path = Path()
    ..moveTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..lineTo(p3.dx, p3.dy)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void _drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double dashLength = 6,
  double gapLength = 4,
}) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final distance = _hypot(dx, dy);
  if (distance <= 0.001) return;

  final ux = dx / distance;
  final uy = dy / distance;
  var traveled = 0.0;
  while (traveled < distance) {
    final next = math.min(traveled + dashLength, distance).toDouble();
    canvas.drawLine(
      Offset(start.dx + ux * traveled, start.dy + uy * traveled),
      Offset(start.dx + ux * next, start.dy + uy * next),
      paint,
    );
    traveled += dashLength + gapLength;
  }
}

_WarehouseGraphEdgeStyle _warehouseGraphEdgeStyle(
  _WarehouseGraphEdgeTone tone,
) {
  switch (tone) {
    case _WarehouseGraphEdgeTone.purchase:
      return const _WarehouseGraphEdgeStyle(color: Color(0xFF8B5CF6));
    case _WarehouseGraphEdgeTone.transfer:
      return const _WarehouseGraphEdgeStyle(color: Color(0xFF10B981));
    case _WarehouseGraphEdgeTone.consumption:
      return const _WarehouseGraphEdgeStyle(
        color: Color(0xFFF97316),
        dashed: true,
      );
  }
}

Color _warehouseGraphNodeBorderColor(_WarehouseGraphNodeTone tone) {
  switch (tone) {
    case _WarehouseGraphNodeTone.central:
      return const Color(0xFFBFDBFE);
    case _WarehouseGraphNodeTone.project:
      return const Color(0xFFA7F3D0);
    case _WarehouseGraphNodeTone.hot:
      return const Color(0xFFFED7AA);
    case _WarehouseGraphNodeTone.buy:
      return const Color(0xFFDDD6FE);
    case _WarehouseGraphNodeTone.consumed:
      return const Color(0xFFD1D5DB);
  }
}

Color _warehouseGraphNodeIconColor(_WarehouseGraphNodeTone tone) {
  switch (tone) {
    case _WarehouseGraphNodeTone.central:
      return const Color(0xFF2563EB);
    case _WarehouseGraphNodeTone.project:
      return const Color(0xFF059669);
    case _WarehouseGraphNodeTone.hot:
      return const Color(0xFFEA580C);
    case _WarehouseGraphNodeTone.buy:
      return const Color(0xFF7C3AED);
    case _WarehouseGraphNodeTone.consumed:
      return const Color(0xFF475569);
  }
}

IconData _warehouseGraphNodeIcon(_WarehouseGraphNodeTone tone) {
  switch (tone) {
    case _WarehouseGraphNodeTone.central:
      return Icons.inventory_2_outlined;
    case _WarehouseGraphNodeTone.project:
      return Icons.apartment_outlined;
    case _WarehouseGraphNodeTone.hot:
      return Icons.local_fire_department_outlined;
    case _WarehouseGraphNodeTone.buy:
      return Icons.shopping_cart_outlined;
    case _WarehouseGraphNodeTone.consumed:
      return Icons.task_alt_outlined;
  }
}
