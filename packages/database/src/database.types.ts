export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      aircraft_lease_contracts: {
        Row: {
          activated_at: string
          aircraft_id: string | null
          cadence_hours: number
          company_id: string | null
          created_at: string
          currency_code: string
          duration_days: number
          ends_at: string
          grace_hours: number
          id: string
          initial_payment_minor: number
          offer_id: string
          reference_price_minor: number
          rent_minor: number
          schema_version: number
          state: string
          terminate_effective_at: string | null
          terminated_at: string | null
          termination_penalty_minor: number
          terms_version: number
          usable_during_grace: boolean
          voluntary_termination: boolean
        }
        Insert: {
          activated_at: string
          aircraft_id?: string | null
          cadence_hours: number
          company_id?: string | null
          created_at?: string
          currency_code: string
          duration_days: number
          ends_at: string
          grace_hours: number
          id?: string
          initial_payment_minor: number
          offer_id: string
          reference_price_minor: number
          rent_minor: number
          schema_version?: number
          state?: string
          terminate_effective_at?: string | null
          terminated_at?: string | null
          termination_penalty_minor: number
          terms_version: number
          usable_during_grace: boolean
          voluntary_termination: boolean
        }
        Update: {
          activated_at?: string
          aircraft_id?: string | null
          cadence_hours?: number
          company_id?: string | null
          created_at?: string
          currency_code?: string
          duration_days?: number
          ends_at?: string
          grace_hours?: number
          id?: string
          initial_payment_minor?: number
          offer_id?: string
          reference_price_minor?: number
          rent_minor?: number
          schema_version?: number
          state?: string
          terminate_effective_at?: string | null
          terminated_at?: string | null
          termination_penalty_minor?: number
          terms_version?: number
          usable_during_grace?: boolean
          voluntary_termination?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "aircraft_lease_contracts_aircraft_id_fkey"
            columns: ["aircraft_id"]
            isOneToOne: true
            referencedRelation: "company_aircraft"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "aircraft_lease_contracts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "aircraft_lease_contracts_offer_id_fkey"
            columns: ["offer_id"]
            isOneToOne: true
            referencedRelation: "aircraft_purchase_offers"
            referencedColumns: ["id"]
          },
        ]
      }
      aircraft_lease_installments: {
        Row: {
          amount_minor: number
          contract_id: string
          created_at: string
          currency_code: string
          due_at: string
          grace_until: string | null
          id: string
          installment_number: number
          ledger_entry_id: string | null
          paid_at: string | null
          schema_version: number
          state: string
        }
        Insert: {
          amount_minor: number
          contract_id: string
          created_at?: string
          currency_code: string
          due_at: string
          grace_until?: string | null
          id?: string
          installment_number: number
          ledger_entry_id?: string | null
          paid_at?: string | null
          schema_version?: number
          state: string
        }
        Update: {
          amount_minor?: number
          contract_id?: string
          created_at?: string
          currency_code?: string
          due_at?: string
          grace_until?: string | null
          id?: string
          installment_number?: number
          ledger_entry_id?: string | null
          paid_at?: string | null
          schema_version?: number
          state?: string
        }
        Relationships: [
          {
            foreignKeyName: "aircraft_lease_installments_contract_id_fkey"
            columns: ["contract_id"]
            isOneToOne: false
            referencedRelation: "aircraft_lease_contracts"
            referencedColumns: ["id"]
          },
        ]
      }
      aircraft_purchase_offers: {
        Row: {
          aircraft_type_code: string
          cadence_hours: number | null
          created_at: string
          currency_code: string
          display_name: string
          duration_days: number | null
          grace_hours: number | null
          id: string
          initial_payment_minor: number | null
          offer_kind: string
          price_minor: number
          rent_minor: number | null
          schema_version: number
          seller_kind: string
          serial_number: string
          sold_at: string | null
          status: string
          termination_penalty_minor: number | null
          terms_version: number | null
          usable_during_grace: boolean | null
          voluntary_termination: boolean | null
        }
        Insert: {
          aircraft_type_code: string
          cadence_hours?: number | null
          created_at?: string
          currency_code: string
          display_name: string
          duration_days?: number | null
          grace_hours?: number | null
          id: string
          initial_payment_minor?: number | null
          offer_kind?: string
          price_minor: number
          rent_minor?: number | null
          schema_version?: number
          seller_kind?: string
          serial_number: string
          sold_at?: string | null
          status?: string
          termination_penalty_minor?: number | null
          terms_version?: number | null
          usable_during_grace?: boolean | null
          voluntary_termination?: boolean | null
        }
        Update: {
          aircraft_type_code?: string
          cadence_hours?: number | null
          created_at?: string
          currency_code?: string
          display_name?: string
          duration_days?: number | null
          grace_hours?: number | null
          id?: string
          initial_payment_minor?: number | null
          offer_kind?: string
          price_minor?: number
          rent_minor?: number | null
          schema_version?: number
          seller_kind?: string
          serial_number?: string
          sold_at?: string | null
          status?: string
          termination_penalty_minor?: number | null
          terms_version?: number | null
          usable_during_grace?: boolean | null
          voluntary_termination?: boolean | null
        }
        Relationships: []
      }
      airports: {
        Row: {
          icao_code: string
          latitude: number
          longitude: number
          name: string
          popularity_tier: string
          schema_version: number
        }
        Insert: {
          icao_code: string
          latitude: number
          longitude: number
          name: string
          popularity_tier: string
          schema_version?: number
        }
        Update: {
          icao_code?: string
          latitude?: number
          longitude?: number
          name?: string
          popularity_tier?: string
          schema_version?: number
        }
        Relationships: []
      }
      companies: {
        Row: {
          created_at: string
          id: string
          name: string
          owner_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          owner_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          owner_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      company_aircraft: {
        Row: {
          acquired_at: string
          acquisition_kind: string
          aircraft_type_code: string
          company_id: string
          display_name: string
          id: string
          is_usable: boolean
          offer_id: string
          schema_version: number
          serial_number: string
        }
        Insert: {
          acquired_at?: string
          acquisition_kind?: string
          aircraft_type_code: string
          company_id: string
          display_name: string
          id?: string
          is_usable?: boolean
          offer_id: string
          schema_version?: number
          serial_number: string
        }
        Update: {
          acquired_at?: string
          acquisition_kind?: string
          aircraft_type_code?: string
          company_id?: string
          display_name?: string
          id?: string
          is_usable?: boolean
          offer_id?: string
          schema_version?: number
          serial_number?: string
        }
        Relationships: [
          {
            foreignKeyName: "company_aircraft_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "company_aircraft_offer_id_fkey"
            columns: ["offer_id"]
            isOneToOne: true
            referencedRelation: "aircraft_purchase_offers"
            referencedColumns: ["id"]
          },
        ]
      }
      flight_dispatches: {
        Row: {
          aircraft_id: string
          arrival_icao: string
          closed_at: string | null
          company_id: string
          created_at: string
          departure_icao: string
          id: string
          schema_version: number
          started_at: string | null
          state: string
        }
        Insert: {
          aircraft_id: string
          arrival_icao: string
          closed_at?: string | null
          company_id: string
          created_at?: string
          departure_icao: string
          id?: string
          schema_version?: number
          started_at?: string | null
          state?: string
        }
        Update: {
          aircraft_id?: string
          arrival_icao?: string
          closed_at?: string | null
          company_id?: string
          created_at?: string
          departure_icao?: string
          id?: string
          schema_version?: number
          started_at?: string | null
          state?: string
        }
        Relationships: [
          {
            foreignKeyName: "flight_dispatches_aircraft_id_fkey"
            columns: ["aircraft_id"]
            isOneToOne: false
            referencedRelation: "company_aircraft"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "flight_dispatches_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      cancel_account_deletion: {
        Args: { idempotency_key: string; request_id: string }
        Returns: Json
      }
      close_flight: {
        Args: {
          dispatch_id: string
          idempotency_key: string
          owner_id: string
          report: Json
        }
        Returns: Json
      }
      create_company_with_opening_balance: {
        Args: {
          company_name: string
          currency_code: string
          idempotency_key: string
          opening_amount_minor: number
          owner_id: string
        }
        Returns: Json
      }
      create_dispatch_draft: {
        Args: {
          aircraft_id: string
          arrival_icao: string
          departure_icao: string
          idempotency_key: string
          owner_id: string
        }
        Returns: Json
      }
      finalize_account_deletion: { Args: { request_id: string }; Returns: Json }
      get_account_export: { Args: { request_id: string }; Returns: Json }
      get_company_aircraft: {
        Args: never
        Returns: {
          acquired_at: string
          acquisition_kind: string
          aircraft_id: string
          aircraft_type_code: string
          display_name: string
          offer_id: string
          schema_version: number
          serial_number: string
        }[]
      }
      get_company_ledger: {
        Args: never
        Returns: {
          amount_minor: number
          currency_code: string
          entry_id: string
          entry_type: string
          recorded_at: string
          schema_version: number
          sequence_number: number
        }[]
      }
      get_company_reputation: {
        Args: never
        Returns: {
          event_count: number
          schema_version: number
          score: number
        }[]
      }
      lease_aircraft: {
        Args: { idempotency_key: string; offer_id: string; owner_id: string }
        Returns: Json
      }
      post_company_opening_balance: {
        Args: {
          amount_minor: number
          company_id: string
          currency_code: string
          idempotency_key: string
        }
        Returns: Json
      }
      process_aircraft_lease: {
        Args: {
          contract_id: string
          effective_at?: string
          idempotency_key: string
        }
        Returns: Json
      }
      purchase_aircraft: {
        Args: { idempotency_key: string; offer_id: string; owner_id: string }
        Returns: Json
      }
      replay_account_deletion_event: {
        Args: {
          completed_at: string
          event_schema_version: number
          export_schema_version: number
          marker_id: string
          request_token_hash: string
          subject_token: string
        }
        Returns: Json
      }
      request_account_deletion: {
        Args: { idempotency_key: string }
        Returns: Json
      }
      start_flight_from_dispatch: {
        Args: { dispatch_id: string; idempotency_key: string; owner_id: string }
        Returns: Json
      }
      terminate_aircraft_lease: {
        Args: { contract_id: string; idempotency_key: string; owner_id: string }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
