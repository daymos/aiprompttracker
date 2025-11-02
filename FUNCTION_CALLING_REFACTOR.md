# Function Calling Refactor - URGENT

## Current Problem

The system uses a **broken two-step approach**:
1. Ask LLM "does user want keyword research?" (separate call)
2. If yes → call API
3. Then generate response

This is **fundamentally wrong** for a conversational SEO assistant.

## What It Should Be

**Single unified flow with function calling:**

```python
# Define tools the LLM can use
tools = [
    {
        "name": "research_keywords",
        "description": "Get keyword data with search volume and competition",
        "parameters": {"keyword_or_topic": "string"}
    },
    {
        "name": "analyze_backlinks",
        "description": "Analyze backlink profile for a domain",
        "parameters": {"domain": "string"}
    }
]

# LLM responds with conversation
response = await llm.chat(messages, tools=tools)

# If LLM wants to use tools:
if response.tool_calls:
    for tool_call in response.tool_calls:
        if tool_call.function.name == "research_keywords":
            result = await keyword_service.analyze_keywords(...)
            # Feed result back to LLM
            
    # LLM generates final response with tool results
    final_response = await llm.chat(messages + tool_results)
```

## Implementation Steps

### 1. Update `llm_service.py`

Add new method:
```python
async def chat_with_tools(
    self,
    user_message: str,
    conversation_history: List[Dict],
    tools: List[Dict],
    tool_executor_callback: Callable
) -> tuple[str, Optional[str]]:
    """
    Chat with function calling support.
    
    Args:
        user_message: Current user message
        conversation_history: Previous messages
        tools: Available functions
        tool_executor_callback: Async function to execute tools
        
    Returns:
        (response_text, reasoning)
    """
```

### 2. Update `keyword_chat.py`

Replace the entire intent detection block with:
```python
# Define available tools
tools = [...]

# Chat with tools
async def execute_tool(tool_name, args):
    if tool_name == "research_keywords":
        return await keyword_service.analyze_keywords(...)
    elif tool_name == "analyze_backlinks":
        return await backlink_service.get_backlinks(...)

response, reasoning = await llm_service.chat_with_tools(
    user_message=request.message,
    conversation_history=conversation_history,
    tools=tools,
    tool_executor_callback=execute_tool
)
```

### 3. Remove Dead Code

Delete:
- `extract_keyword_intent()`
- `extract_backlink_intent()`
- All the separate intent detection logic

## Benefits

✅ Natural conversation flow
✅ LLM decides when to use tools
✅ No more broken "intent detection"
✅ Supports multiple tool calls in one turn
✅ Cleaner architecture

## Groq Function Calling Support

Groq supports OpenAI-compatible function calling:
```python
response = await client.chat.completions.create(
    model="openai/gpt-oss-120b",
    messages=messages,
    tools=tools,
    tool_choice="auto"  # Let LLM decide
)

if response.choices[0].message.tool_calls:
    # LLM wants to use tools
    for tool_call in response.choices[0].message.tool_calls:
        function_name = tool_call.function.name
        arguments = json.loads(tool_call.function.arguments)
        # Execute and feed back result
```

## Priority: CRITICAL

This is the core of the application. Without proper function calling, the assistant can't provide SEO insights naturally.

