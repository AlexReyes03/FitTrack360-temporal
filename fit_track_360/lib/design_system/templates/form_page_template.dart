import 'package:flutter/material.dart';
import '../tokens/app_spacing.dart';
import 'app_scaffold_template.dart';

class FormPageTemplate extends StatelessWidget {
  final Widget? header;
  final Widget fields;
  final Widget? primaryCta;

  const FormPageTemplate({
    super.key,
    this.header,
    required this.fields,
    this.primaryCta,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffoldTemplate(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) ...[
                    header!,
                    const SizedBox(height: AppSpacing.md),
                  ],
                  fields,
                  if (primaryCta != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    primaryCta!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
