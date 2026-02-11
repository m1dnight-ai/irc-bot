claude-code
```

This starts an interactive session where Claude can execute commands, create files, etc.

## The Prompt

Here's a solid prompt to give it:
```
I want you to build a modular IRC bot with the following features:

1. **IRC Bot Core**
   - Connect to IRC servers
   - Join channels
   - Respond to messages
   - Plugin/module system where I can easily add new plugins later

2. **Initial Plugins**
   - Karma system: users can do "username++" or "username--" to award/remove karma points
   - Karma tracking and storage (persist across restarts)
   - Command to check karma scores

3. **Real-time Web Dashboard**
   - Show live channel activity
   - Display current users in channel
   - Show karma leaderboard
   - Real-time updates (use websockets)

4. **Local IRC Server for Testing**
   - Set up a lightweight local IRC server (like ngircd or inspircd)
   - Configuration to make testing easy

5. **Test Suite**
   - Unit tests for plugin system
   - Integration tests for IRC functionality
   - Tests for karma plugin

**Technical requirements:**
- Use Elixir and Phoenix LiveView 
- Make the plugin system simple and well-documented
- Include a README with setup and usage instructions
- The bot should be production-ready with proper error handling
- Try to avoid big functions, keep functions small enough so that Uncle Bob would approve.
- All code should be documented properly.

Please set everything up, get it running, and verify it works end-to-end.
