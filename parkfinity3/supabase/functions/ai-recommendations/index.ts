import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY') ?? '';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { user_preferences, available_listings } = await req.json();

    if (!user_preferences || !available_listings || available_listings.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing preferences or listings data' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      );
    }

    if (!GROQ_API_KEY) {
      throw new Error('Groq API Key is not configured on the server.');
    }

    // Prompt engineering for Groq API
    const systemPrompt = `You are an AI parking recommendation engine. 
Given a user's preferences (budget, preferred distance, vehicle type, security needs) and a JSON list of available parking listings, 
your job is to rank the top 3 best parking spots from the list.
Respond ONLY with a JSON array containing the 'id' of the listings in ranked order, and a short 'reason' string for why it was chosen.`;

    const userPrompt = `Preferences: ${JSON.stringify(user_preferences)}\nListings: ${JSON.stringify(available_listings)}`;

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${GROQ_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama3-8b-8192',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.2,
        response_format: { type: "json_object" }
      })
    });

    const aiData = await response.json();
    
    if (aiData.error) {
      throw new Error(`Groq Error: ${aiData.error.message}`);
    }

    // Parse the AI's JSON output
    const recommendations = JSON.parse(aiData.choices[0].message.content);

    return new Response(
      JSON.stringify({ recommendations }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error: any) {
    console.error('AI Recommendation Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal Server Error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
