import { useState } from "react";
import { useProtocolCapabilities } from "./useProtocolCapabilities";

export type ProposalActionInput = {
  id: string;
  target: string;
  value: string;
  calldata: string;
};

export type ProposalComposerModel = {
  title: string;
  setTitle: (value: string) => void;

  description: string;
  setDescription: (value: string) => void;

  actions: ProposalActionInput[];
  addAction: () => void;
  updateAction: (
    id: string,
    field: keyof Omit<ProposalActionInput, "id">,
    value: string
  ) => void;
  removeAction: (id: string) => void;

  votingPower: string;
  proposalThreshold: string;
  meetsThreshold: boolean;

  isSubmitting: boolean;
  capabilities: ReturnType<typeof useProtocolCapabilities>;
};

export function useProposalComposerModel(): ProposalComposerModel {
  const capabilities = useProtocolCapabilities();

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [actions, setActions] = useState<ProposalActionInput[]>([
    {
      id: crypto.randomUUID(),
      target: "",
      value: "0",
      calldata: "",
    },
  ]);

  const [isSubmitting] = useState(false);

  const votingPower = "0 GOV";
  const proposalThreshold = "4%";
  const meetsThreshold = capabilities.canCreateProposal;

  const addAction = () => {
    setActions((prev) => [
      ...prev,
      {
        id: crypto.randomUUID(),
        target: "",
        value: "0",
        calldata: "",
      },
    ]);
  };

  const updateAction = (
    id: string,
    field: keyof Omit<ProposalActionInput, "id">,
    value: string
  ) => {
    setActions((prev) =>
      prev.map((action) =>
        action.id === id ? { ...action, [field]: value } : action
      )
    );
  };

  const removeAction = (id: string) => {
    setActions((prev) => prev.filter((action) => action.id !== id));
  };

  // TODO:
  // proposalThreshold -> DaoGovernor.proposalThreshold()
  // votingPower -> Governance token / IVotes.getVotes(user, blockNumber)
  // meetsThreshold -> comparación real votingPower >= proposalThreshold
  //
  // submit final:
  // targets = actions.map(a => a.target)
  // values = actions.map(a => a.value)
  // calldatas = actions.map(a => a.calldata)
  // description = texto final de propuesta
  //
  // write:
  // DaoGovernor.propose(targets, values, calldatas, description)
  //
  // agregar validaciones reales:
  // - target address válido
  // - calldata válido
  // - arrays no vacíos
  // - description obligatoria

  return {
    title,
    setTitle,
    description,
    setDescription,
    actions,
    addAction,
    updateAction,
    removeAction,
    votingPower,
    proposalThreshold,
    meetsThreshold,
    isSubmitting,
    capabilities,
  };
}