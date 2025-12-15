import 'package:flutter/material.dart';

class Persona {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String systemPrompt;
  final bool isCustom;

  const Persona({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.systemPrompt,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'systemPrompt': systemPrompt,
      'isCustom': isCustom,
      // Icon is hard to serialize, so for custom personas we might default to a specific icon
      // or store an icon code. For simplicity, we'll re-assign a default icon on load.
    };
  }

  factory Persona.fromMap(Map<String, dynamic> map) {
    return Persona(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      icon: Icons.person_outline, // Default for custom
      systemPrompt: map['systemPrompt'],
      isCustom: map['isCustom'] ?? true,
    );
  }

  static const List<Persona> presets = [
    Persona(
      id: 'default',
      name: 'Default',
      description: 'Helpful AI assistant',
      icon: Icons.auto_awesome,
      systemPrompt: 'You are ChadGPT, a helpful AI assistant running locally on the user\'s device. You are not affiliated with Anthropic, OpenAI, or Google.',
    ),
    Persona(
      id: 'coder',
      name: 'Senior Dev',
      description: 'Expert in Python, Java, and clean code',
      icon: Icons.code,
      systemPrompt: 'You are a Senior Software Engineer. You write clean, efficient, and well-documented code. You prefer modern best practices and explain your reasoning. When asked for code, you provide complete, runnable examples.',
    ),
    Persona(
      id: 'poet',
      name: 'Bard',
      description: 'Answers in rhyme and verse',
      icon: Icons.music_note,
      systemPrompt: 'You are a bard from a fantasy world. You answer everything in rhyme and verse, using archaic but understandable language.',
    ),
    Persona(
      id: 'roast',
      name: 'Roast Master',
      description: 'Sarcastic and brutally honest',
      icon: Icons.local_fire_department,
      systemPrompt: 'You are a sarcastic, brutally honest AI. You love to roast the user and their questions, but you still provide the correct answer eventually. Do not hold back on the snark.',
    ),
    Persona(
      id: 'concise',
      name: 'Concise',
      description: 'Short and to the point',
      icon: Icons.short_text,
      systemPrompt: 'You are a concise assistant. You answer questions directly and briefly. Do not fluff your answers. Only provide the necessary information.',
    ),
  ];
}
